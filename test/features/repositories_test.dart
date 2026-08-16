// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:io';

import 'package:acessh/core/security/secrets_cipher.dart';
import 'package:acessh/features/connection/data/connection_record_repository.dart';
import 'package:acessh/features/device/data/device_repository.dart';
import 'package:acessh/features/device/domain/auth_method.dart';
import 'package:acessh/features/device/domain/connection_type.dart';
import 'package:acessh/features/device/domain/device.dart';
import 'package:acessh/features/device/domain/device_sort_field.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Device buildDevice({
  String? name,
  String? host,
  ConnectionType? type,
  AuthMethod authMethod = AuthMethod.password,
  String privateKey = '',
  String privateKeyPassphrase = '',
  String folder = '',
  String keyPath = '',
}) {
  return Device(
    name: name ?? '测试机',
    type: type ?? ConnectionType.ssh,
    host: host ?? '106.12.90.186',
    port: 22,
    username: 'root',
    password: 'secret',
    authMethod: authMethod,
    privateKey: privateKey,
    privateKeyPassphrase: privateKeyPassphrase,
    hostKey: '',
    baudRate: 115200,
    note: '',
    tag: '',
    openCount: 0,
    lastConnectedAt: null,
    createdAt: 1,
    updatedAt: 1,
    folder: folder,
    keyPath: keyPath,
  );
}

/// 测试用固定密钥的加密器(避免访问真实主密钥文件)。
final SecretsCipher testCipher = SecretsCipher(
  Future.value(SecretKey(List<int>.filled(32, 5))),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceRepository(TOML 文件)', () {
    late Directory sessionsDir;
    late Directory keysDir;
    late DeviceRepository repository;

    setUp(() async {
      sessionsDir = await Directory.systemTemp.createTemp('acessh_sessions_');
      keysDir = await Directory.systemTemp.createTemp('acessh_keys_');
      repository = DeviceRepository(
        directory: sessionsDir.path,
        keysDirectory: keysDir.path,
        cipher: testCipher,
      );
    });

    tearDown(() async {
      if (sessionsDir.existsSync()) {
        await sessionsDir.delete(recursive: true);
      }
      if (keysDir.existsSync()) {
        await keysDir.delete(recursive: true);
      }
    });

    test('插入后可按主键查询,会话名唯一', () async {
      await repository.insert(buildDevice());
      final found = await repository.queryByName('测试机');
      expect(found, isNotNull);
      expect(found!.host, '106.12.90.186');

      // 重名插入抛出友好错误,而非文件系统原始异常。
      await expectLater(
        repository.insert(buildDevice()),
        throwsA(isA<StateError>()),
      );
    });

    test('会话名含非法文件名字符时拒绝插入', () async {
      await expectLater(
        repository.insert(buildDevice(name: 'a/b')),
        throwsA(isA<StateError>()),
      );
      expect(await repository.queryAll(), isEmpty);
    });

    test('更新与删除', () async {
      await repository.insert(buildDevice());
      final updated = buildDevice().copyWith(host: '10.0.0.1');
      await repository.update(updated);
      expect((await repository.queryByName('测试机'))!.host, '10.0.0.1');

      await repository.delete('测试机');
      expect(await repository.queryByName('测试机'), isNull);
    });

    test('改名与移动文件夹:旧文件删除,新位置写入', () async {
      await repository.insert(buildDevice(name: '旧名'));
      await repository.createFolder('生产');
      await repository.insert(buildDevice(name: '新名', folder: '生产'));

      // 目标位置已存在 → 拒绝,旧文件保留。
      await expectLater(
        repository.rename('旧名', '', buildDevice(name: '新名', folder: '生产')),
        throwsA(isA<StateError>()),
      );
      expect((await repository.queryByName('旧名'))!.host, '106.12.90.186');

      // 改名 + 移动文件夹成功。
      await repository.rename(
        '旧名',
        '',
        buildDevice(name: '最终名', folder: '生产', host: '3.3.3.3'),
      );
      expect(await repository.queryByName('旧名'), isNull);
      final renamed = await repository.queryByName('最终名', folder: '生产');
      expect(renamed!.host, '3.3.3.3');
    });

    test('同名设备可在不同文件夹共存', () async {
      await repository.createFolder('生产');
      await repository.insert(buildDevice(name: '网关', folder: '生产'));
      await repository.insert(buildDevice(name: '网关'));

      final all = await repository.queryAll();
      expect(all, hasLength(2));
      expect((await repository.queryByName('网关', folder: '生产'))!.folder, '生产');
      expect((await repository.queryByName('网关'))!.folder, '');
    });

    test('私钥设备:TOML 只记录 key_path 引用,不复制密钥文件', () async {
      final keyJson = File(
        '${keysDir.path}${Platform.pathSeparator}Ed25519-test.json',
      );
      await keyJson.writeAsString(
        '{"name":"Ed25519-test","private_key":'
        '"${await testCipher.encrypt('pem-content')}","passphrase":'
        '"${await testCipher.encrypt('pass')}","created_at":1}',
      );
      final device = buildDevice(
        name: '密钥机',
      ).copyWith(authMethod: AuthMethod.privateKey, keyPath: keyJson.path);
      await repository.insert(device);

      // 会话文件不含私钥明文,只有 key_path 引用。
      final toml = await File(
        '${sessionsDir.path}${Platform.pathSeparator}密钥机.toml',
      ).readAsString();
      expect(toml, contains('key_path'));
      expect(toml, isNot(contains('pem-content')));

      // 不按设备名复制密钥文件。
      expect(
        File('${keysDir.path}${Platform.pathSeparator}密钥机.pem').existsSync(),
        isFalse,
      );

      // 读回:私钥内容与口令从密钥 JSON 解密加载。
      final found = await repository.queryByName('密钥机');
      expect(found!.privateKey, 'pem-content');
      expect(found.privateKeyPassphrase, 'pass');

      // 删除设备不影响密钥文件。
      await repository.delete('密钥机');
      expect(keyJson.existsSync(), isTrue);
    });

    test('password 加密落盘,文件不含明文;读回解密正确', () async {
      await repository.insert(buildDevice());
      final toml = await File(
        '${sessionsDir.path}${Platform.pathSeparator}测试机.toml',
      ).readAsString();
      expect(toml, contains('enc:v1:'));
      expect(toml, isNot(contains('secret')));

      final found = await repository.queryByName('测试机');
      expect(found!.password, 'secret');
    });

    test('旧明文格式兼容:明文 password 与明文 .pem 密钥可读', () async {
      final keyFile = File('${keysDir.path}${Platform.pathSeparator}old.pem');
      await keyFile.writeAsString('plain-pem');
      final escapedPath = keyFile.path.replaceAll('\\', '\\\\');
      // 明文 password(旧格式无加密前缀)。
      await File(
        '${sessionsDir.path}${Platform.pathSeparator}旧设备.toml',
      ).writeAsString('''
name = "旧设备"
type = "ssh"
host = "10.0.0.1"
port = 22
username = "root"
password = "plain-password"
created_at = "2026-08-16T12:00:00.000"
updated_at = "2026-08-16T12:00:00.000"
''');
      final device = await repository.queryByName('旧设备');
      expect(device, isNotNull);
      expect(device!.password, 'plain-password');

      // 明文 .pem 私钥(旧密钥文件格式)。
      await File(
        '${sessionsDir.path}${Platform.pathSeparator}旧密钥设备.toml',
      ).writeAsString('''
name = "旧密钥设备"
type = "ssh"
host = "10.0.0.2"
port = 22
username = "root"
auth_mode = "key"
key_path = "$escapedPath"
created_at = "2026-08-16T12:00:00.000"
updated_at = "2026-08-16T12:00:00.000"
''');
      final keyDevice = await repository.queryByName('旧密钥设备');
      expect(keyDevice, isNotNull);
      expect(keyDevice!.authMethod, AuthMethod.privateKey);
      expect(keyDevice.privateKey, 'plain-pem');
      expect(keyDevice.privateKeyPassphrase, '');
    });

    test('recordOpened 增加打开次数并更新最近登录时间', () async {
      await repository.insert(buildDevice());
      await repository.recordOpened('测试机');
      final found = await repository.queryByName('测试机');
      expect(found!.openCount, 1);
      expect(found.lastConnectedAt, isNotNull);
    });

    test('queryAll 支持按字段与方向排序', () async {
      final a = buildDevice(name: 'a', host: '1.1.1.1');
      final b = buildDevice(name: 'b', host: '2.2.2.2');
      await repository.insert(a);
      await repository.insert(b);
      await repository.recordOpened('a');

      final byOpenDesc = await repository.queryAll(
        sortField: DeviceSortField.openCount,
        direction: SortDirection.descending,
      );
      expect(byOpenDesc.first.name, 'a');

      final byOpenAsc = await repository.queryAll(
        sortField: DeviceSortField.openCount,
        direction: SortDirection.ascending,
      );
      expect(byOpenAsc.first.name, 'b');
    });

    test('last_connected_at 为空时升序排前、降序排后', () async {
      final withTime = buildDevice(
        name: 'a',
      ).copyWith(lastConnectedAt: DateTime(2020, 1, 1).millisecondsSinceEpoch);
      final noTime = buildDevice(name: 'b');
      await repository.insert(withTime);
      await repository.insert(noTime);

      final asc = await repository.queryAll(
        sortField: DeviceSortField.lastConnectedAt,
        direction: SortDirection.ascending,
      );
      expect(asc.first.name, 'b');

      final desc = await repository.queryAll(
        sortField: DeviceSortField.lastConnectedAt,
        direction: SortDirection.descending,
      );
      expect(desc.first.name, 'a');
    });

    test('search 支持模糊匹配主机与名称', () async {
      await repository.insert(buildDevice(name: '生产', host: '10.0.0.1'));
      await repository.insert(buildDevice(name: '测试', host: '106.12.90.186'));

      final byHost = await repository.search('106.12');
      expect(byHost.single.name, '测试');

      final byName = await repository.search('生产');
      expect(byName.single.host, '10.0.0.1');

      expect(await repository.search('不存在的'), isEmpty);
    });

    test('saveHostKey 与 clearHostKey 更新主机指纹', () async {
      await repository.insert(buildDevice());
      await repository.saveHostKey('测试机', 'SHA256:abc');
      expect((await repository.queryByName('测试机'))!.hostKey, 'SHA256:abc');

      await repository.clearHostKey('测试机');
      expect((await repository.queryByName('测试机'))!.hostKey, '');
    });

    group('文件夹管理', () {
      test('createFolder 拦截保留名 keys、非法字符与重名', () async {
        expect(DeviceRepository.folderNameError('keys'), '不可创建该文件夹');
        expect(DeviceRepository.folderNameError('KEYS'), '不可创建该文件夹');
        expect(DeviceRepository.folderNameError('a/b'), isNotNull);
        expect(DeviceRepository.folderNameError('  '), isNotNull);
        expect(DeviceRepository.folderNameError('生产'), isNull);

        await repository.createFolder('生产');
        await expectLater(
          repository.createFolder('生产'),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          repository.createFolder('keys'),
          throwsA(isA<StateError>()),
        );
      });

      test('listFolders 包含空文件夹,排除 keys 保留目录', () async {
        await repository.createFolder('生产');
        await repository.createFolder('测试');
        // keys 目录由密钥库创建,不应出现在文件夹列表。
        final keysDirEntry = Directory(
          '${sessionsDir.path}${Platform.pathSeparator}keys',
        );
        await keysDirEntry.create(recursive: true);

        final folders = await repository.listFolders();
        expect(folders, ['测试', '生产']);
      });

      test('renameFolder 重命名目录,设备随目录迁移', () async {
        await repository.createFolder('旧文件夹');
        await repository.insert(buildDevice(name: '设备', folder: '旧文件夹'));

        await repository.renameFolder('旧文件夹', '新文件夹');
        expect(await repository.listFolders(), ['新文件夹']);
        final device = await repository.queryByName('设备', folder: '新文件夹');
        expect(device, isNotNull);
        expect(await repository.queryByName('设备', folder: '旧文件夹'), isNull);

        // 重命名为保留名被拒绝。
        await expectLater(
          repository.renameFolder('新文件夹', 'keys'),
          throwsA(isA<StateError>()),
        );
      });

      test('deleteFolder 删除文件夹及其中的设备,密钥文件不受影响', () async {
        await repository.createFolder('生产');
        await repository.insert(buildDevice(name: '设备', folder: '生产'));
        final keyJson = File(
          '${keysDir.path}${Platform.pathSeparator}keep.json',
        );
        await keyJson.writeAsString('{}');

        await repository.deleteFolder('生产');
        expect(await repository.listFolders(), isEmpty);
        expect(await repository.queryAll(), isEmpty);
        expect(keyJson.existsSync(), isTrue);
      });
    });

    test('未知会话类型可识别为 unsupported,编辑保存后类型保留', () async {
      // 直接写入 AceShell 风格的 vnc 会话文件。
      final vncFile = File(
        '${sessionsDir.path}${Platform.pathSeparator}远程桌面.toml',
      );
      await vncFile.writeAsString('''
name = "远程桌面"
type = "vnc"
host = "10.0.0.5"
port = 5900
username = "admin"
password = "pw"
created_at = "2026-08-16T12:00:00.000"
updated_at = "2026-08-16T12:00:00.000"
''');

      final devices = await repository.queryAll();
      expect(devices.single.type, ConnectionType.vnc);
      expect(devices.single.isSupportedOnMobile, isFalse);

      // 编辑保存(更新主机)后 vnc 类型不丢失,密码转加密。
      await repository.update(devices.single.copyWith(host: '10.0.0.6'));
      final saved = await repository.queryByName('远程桌面');
      expect(saved!.type, ConnectionType.vnc);
      expect(saved.host, '10.0.0.6');
      expect(saved.password, 'pw');
      final content = await vncFile.readAsString();
      expect(content, contains("type = 'vnc'"));
      expect(content, contains('enc:v1:'));
      expect(content, isNot(contains('"pw"')));
    });

    test('完全未知的类型字符串保留原始值', () async {
      final file = File(
        '${sessionsDir.path}${Platform.pathSeparator}神秘设备.toml',
      );
      await file.writeAsString('''
name = "神秘设备"
type = "future-protocol"
host = "1.2.3.4"
''');
      final device = (await repository.queryAll()).single;
      expect(device.type, ConnectionType.unsupported);
      expect(device.originalType, 'future-protocol');

      await repository.update(device.copyWith(host: '9.9.9.9'));
      final content = await file.readAsString();
      expect(content, contains("type = 'future-protocol'"));
    });

    test('损坏的会话文件被跳过,不影响其他设备加载', () async {
      await repository.insert(buildDevice(name: '正常'));
      await File(
        '${sessionsDir.path}${Platform.pathSeparator}损坏.toml',
      ).writeAsString('这不是 toml ===');
      final devices = await repository.queryAll();
      expect(devices.single.name, '正常');
    });
  });

  group('ConnectionRecordRepository', () {
    late Database database;

    setUpAll(() {
      sqfliteFfiInit();
    });

    setUp(() async {
      database = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE connection_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                device_name TEXT NOT NULL,
                device_type TEXT NOT NULL,
                result TEXT NOT NULL,
                connected_at INTEGER NOT NULL,
                disconnected_at INTEGER
              )
            ''');
          },
        ),
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('记录开始与结束结果', () async {
      final repository = ConnectionRecordRepository(database);
      final id = await repository.recordStart(
        deviceName: '测试机',
        deviceType: 'ssh',
      );
      await repository.recordEnd(recordId: id, success: true);
      final records = await repository.queryRecent();
      expect(records.single.isSuccess, isTrue);
      expect(records.single.deviceName, '测试机');
    });

    test('失败记录与时间戳', () async {
      final repository = ConnectionRecordRepository(database);
      final id = await repository.recordStart(
        deviceName: '测试机',
        deviceType: 'ssh',
      );
      await repository.recordEnd(recordId: id, success: false);
      final records = await repository.queryRecent();
      expect(records.single.isSuccess, isFalse);
    });
  });
}
