// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:toml/toml.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/paths/app_paths.dart';
import '../../../core/security/secrets_cipher.dart';
import '../domain/device.dart';
import '../domain/device_sort_field.dart';

/// 设备仓库:一个设备一个 TOML 会话文件,会话目录下按文件夹分层。
///
/// 目录结构:`sessions/<文件夹>/<会话名>.toml`(文件夹为空时在根目录),
/// 与 AceShell 的会话目录设计对齐;(文件夹, 会话名) 唯一。
/// `sessions/keys/` 为密钥库保留目录,禁止作为用户文件夹名。
///
/// 敏感字段:`password` 在写盘前经 AES-GCM 加密(`enc:v1:` 前缀),
/// 私钥不落盘本目录,设备只通过 `key_path` 引用密钥库中的密钥 JSON。
class DeviceRepository {
  /// 创建设备仓库;不传目录时使用全局会话/密钥目录,测试可注入临时目录。
  DeviceRepository({
    String? directory,
    String? keysDirectory,
    SecretsCipher? cipher,
  }) : _directoryFuture = directory != null
           ? Future.value(Directory(directory))
           : AppPaths.sessionsDirectory(),
       _keysDirectoryFuture = keysDirectory != null
           ? Future.value(Directory(keysDirectory))
           : AppPaths.keysDirectory(),
       _cipher = cipher ?? SecretsCipher.fromMasterKey();

  final Future<Directory> _directoryFuture;
  final Future<Directory> _keysDirectoryFuture;
  final SecretsCipher _cipher;

  /// 会话名/文件夹名中的非法文件名字符。
  static final RegExp _invalidNameChars = RegExp(r'[\\/:*?"<>|\x00-\x1F]');

  /// 校验文件夹名;返回 null 表示合法,否则为错误提示文案。
  static String? folderNameError(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '文件夹名不能为空';
    }
    if (_invalidNameChars.hasMatch(trimmed)) {
      return '文件夹名包含非法字符(\\ / : * ? " < > |)';
    }
    if (trimmed.toLowerCase() == AppConstants.reservedFolderName) {
      return '不可创建该文件夹';
    }
    return null;
  }

  /// 插入新设备;同文件夹下会话名已存在或名称非法时抛出友好错误。
  Future<void> insert(Device device) async {
    _validateName(device.name, device.folder);
    final file = await _fileFor(device.name, device.folder);
    if (await file.exists()) {
      throw StateError('会话名"${device.name}"已存在,请更换名称');
    }
    await _writeDevice(device);
  }

  /// 按会话名与文件夹更新设备(覆盖写)。
  ///
  /// 不校验文件是否存在:文件不存在时等价于新建,
  /// 因此编辑弹窗中修改会话名后保存不会报"设备不存在"。
  Future<void> update(Device device) async {
    _validateName(device.name, device.folder);
    await _writeDevice(device);
  }

  /// 设备改名/移动文件夹:删除旧位置会话文件,按新会话名与文件夹写入。
  ///
  /// 新位置文件已存在或名称非法时抛出友好错误,旧文件保持不变;
  /// 密钥文件由密钥库管理,不随设备迁移。
  Future<void> rename(String oldName, String oldFolder, Device device) async {
    _validateName(device.name, device.folder);
    final newFile = await _fileFor(device.name, device.folder);
    if (await newFile.exists()) {
      throw StateError('会话名"${device.name}"已存在,请更换名称');
    }
    final oldFile = await _fileFor(oldName, oldFolder);
    if (await oldFile.exists()) {
      await oldFile.delete();
    }
    await _writeDevice(device);
  }

  /// 按会话名与文件夹删除设备(密钥文件由密钥库管理,不随设备删除)。
  Future<void> delete(String name, {String folder = ''}) async {
    final file = await _fileFor(name, folder);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 查询全部设备(含各文件夹),按指定字段与方向排序。
  ///
  /// 排序语义对齐原 SQLite 实现:null 的 last_connected_at 在升序时排前、
  /// 降序时排后,次级排序为会话名升序;keys 保留目录不参与扫描。
  Future<List<Device>> queryAll({
    DeviceSortField sortField = DeviceSortField.createdAt,
    SortDirection direction = SortDirection.descending,
  }) async {
    final dir = await _directoryFuture;
    if (!await dir.exists()) {
      return [];
    }
    final devices = <Device>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is! File ||
          !entity.path.endsWith(AppConstants.sessionFileExtension) ||
          entity.path.endsWith('.tmp.toml')) {
        continue;
      }
      final relative = entity.path.substring(dir.path.length + 1);
      final parts = relative.split(Platform.pathSeparator);
      final folder = parts.length > 1 ? parts.first : '';
      if (folder.toLowerCase() == AppConstants.reservedFolderName) {
        continue;
      }
      final device = await _readDevice(entity, folder);
      if (device != null) {
        devices.add(device);
      }
    }
    return _sorted(devices, sortField, direction);
  }

  /// 按会话名与文件夹查询单个设备,不存在或文件损坏返回 null。
  Future<Device?> queryByName(String name, {String folder = ''}) async {
    final file = await _fileFor(name, folder);
    if (!await file.exists()) {
      return null;
    }
    return _readDevice(file, folder);
  }

  /// 模糊搜索:会话名、主机、用户名任一包含关键字(不区分大小写)。
  Future<List<Device>> search(String keyword) async {
    final lower = keyword.toLowerCase();
    final devices = await queryAll();
    return devices
        .where(
          (device) =>
              device.name.toLowerCase().contains(lower) ||
              device.host.toLowerCase().contains(lower) ||
              device.username.toLowerCase().contains(lower),
        )
        .toList();
  }

  /// 记录一次成功连接:打开次数 +1 并更新最近登录时间。
  Future<void> recordOpened(String name, {String folder = ''}) async {
    final device = await queryByName(name, folder: folder);
    if (device == null) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _writeDevice(
      device.copyWith(
        openCount: device.openCount + 1,
        lastConnectedAt: now,
        updatedAt: now,
      ),
    );
  }

  /// 保存设备 SSH 主机指纹(首次连接确认后写入)。
  Future<void> saveHostKey(
    String name,
    String hostKey, {
    String folder = '',
  }) async {
    final device = await queryByName(name, folder: folder);
    if (device == null) {
      return;
    }
    await _writeDevice(
      device.copyWith(
        hostKey: hostKey,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// 清除设备 SSH 主机指纹(用户主动删除后下次连接重新确认)。
  Future<void> clearHostKey(String name, {String folder = ''}) async {
    final device = await queryByName(name, folder: folder);
    if (device == null) {
      return;
    }
    await _writeDevice(
      device.copyWith(
        hostKey: '',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// 全部文件夹名(含空文件夹,排除 keys 保留目录,按名称排序)。
  Future<List<String>> listFolders() async {
    final dir = await _directoryFuture;
    if (!await dir.exists()) {
      return [];
    }
    final folders = <String>[];
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (name.toLowerCase() != AppConstants.reservedFolderName) {
          folders.add(name);
        }
      }
    }
    folders.sort();
    return folders;
  }

  /// 创建文件夹;名称非法或已存在时抛出友好错误。
  Future<void> createFolder(String name) async {
    final error = folderNameError(name);
    if (error != null) {
      throw StateError(error);
    }
    final dir = await _folderDir(name);
    if (await dir.exists()) {
      throw StateError('文件夹"$name"已存在');
    }
    await dir.create(recursive: true);
  }

  /// 重命名文件夹;新名称非法或已存在时抛出友好错误。
  Future<void> renameFolder(String oldName, String newName) async {
    if (oldName == newName) {
      return;
    }
    final error = folderNameError(newName);
    if (error != null) {
      throw StateError(error);
    }
    final oldDir = await _folderDir(oldName);
    if (!await oldDir.exists()) {
      throw StateError('文件夹"$oldName"不存在');
    }
    final newDir = await _folderDir(newName);
    if (await newDir.exists()) {
      throw StateError('文件夹"$newName"已存在');
    }
    await oldDir.rename(newDir.path);
  }

  /// 删除文件夹及其中的全部设备文件(密钥文件不受影响)。
  Future<void> deleteFolder(String name) async {
    final dir = await _folderDir(name);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// 读取会话文件原始字节(导出用,原样携带,不重新序列化)。
  Future<Uint8List> readRawSession(Device device) async {
    final file = await _fileFor(device.name, device.folder);
    return file.readAsBytes();
  }

  /// 按会话名与文件夹写入会话文件原始字节(导入用,原子写)。
  Future<void> writeRawSession(
    String name,
    String folder,
    Uint8List bytes,
  ) async {
    _validateName(name, folder);
    final file = await _fileFor(name, folder);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
  }

  /// 重映射会话文件中的 key_path 引用(导入后指向目标机器密钥库)。
  ///
  /// 仅替换 key_path 字段,其余内容(含密码密文)原样保留。
  Future<void> remapKeyPath(
    String name,
    String folder, {
    required String oldKeyPath,
    required String newKeyPath,
  }) async {
    final file = await _fileFor(name, folder);
    if (!await file.exists()) {
      return;
    }
    final map = TomlDocument.parse(await file.readAsString()).toMap();
    if (map['key_path'] != oldKeyPath) {
      return;
    }
    map['key_path'] = newKeyPath;
    await _writeToml(file, map);
  }

  /// 校验会话名与文件夹名可用作文件路径。
  void _validateName(String name, String folder) {
    if (name.trim().isEmpty) {
      throw StateError('会话名不能为空');
    }
    if (_invalidNameChars.hasMatch(name)) {
      throw StateError('会话名包含非法字符(\\ / : * ? " < > |),请更换名称');
    }
    // 空文件夹视为根目录,不做校验。
    final folderTrimmed = folder.trim();
    if (folderTrimmed.isNotEmpty) {
      final folderError = folderNameError(folderTrimmed);
      if (folderError != null) {
        throw StateError(folderError);
      }
    }
  }

  /// 会话 TOML 文件。
  Future<File> _fileFor(String name, String folder) async {
    final dir = await _directoryFuture;
    final base = folder.isEmpty
        ? dir.path
        : '${dir.path}${Platform.pathSeparator}$folder';
    return File(
      '$base${Platform.pathSeparator}'
      '$name${AppConstants.sessionFileExtension}',
    );
  }

  /// 用户文件夹目录。
  Future<Directory> _folderDir(String name) async {
    final dir = await _directoryFuture;
    return Directory('${dir.path}${Platform.pathSeparator}$name');
  }

  /// 原子写入会话文件:先写临时文件再重命名,避免写一半损坏。
  Future<void> _writeToml(File file, Map<String, Object?> map) async {
    final content = TomlDocument.fromMap(map).toString();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    await tmp.rename(file.path);
  }

  /// 写入设备:password 加密落盘,私钥不落盘(仅写 key_path 引用)。
  Future<void> _writeDevice(Device device) async {
    final map = device.toTomlMap();
    final password = map['password'];
    if (password is String && password.isNotEmpty) {
      map['password'] = await _cipher.encrypt(password);
    }
    final file = await _fileFor(device.name, device.folder);
    await _writeToml(file, map);
  }

  /// 读取单个会话文件;损坏/缺 name 时返回 null 并记录日志(不影响整体)。
  Future<Device?> _readDevice(File file, String folder) async {
    try {
      final map = TomlDocument.parse(await file.readAsString()).toMap();
      // 密码解密;无 enc: 前缀的明文按兼容处理(旧数据/AceShell 文件)。
      final password = map['password'];
      if (password is String && password.isNotEmpty) {
        map['password'] = await _decryptField(password);
      }
      final keyData = await _loadKeyData(map['key_path'] as String? ?? '');
      final fallbackName = file.path
          .split(Platform.pathSeparator)
          .last
          .replaceAll(RegExp('${AppConstants.sessionFileExtension}\$'), '');
      return Device.fromTomlMap(
        map,
        fallbackName: fallbackName,
        folder: folder,
        privateKey: keyData.privateKey,
        privateKeyPassphrase: keyData.passphrase,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.e('解析会话文件失败:${file.path}', error, stackTrace);
      return null;
    }
  }

  /// 按 key_path 加载私钥内容与口令。
  ///
  /// 新格式:密钥库 JSON(private_key/passphrase 为加密字段);
  /// 旧格式兼容:JSON 解析失败时按明文 PEM 读取(口令为空)。
  Future<({String privateKey, String passphrase})> _loadKeyData(
    String keyPath,
  ) async {
    if (keyPath.isEmpty) {
      return (privateKey: '', passphrase: '');
    }
    var file = File(keyPath);
    if (!await file.exists()) {
      // 兼容相对路径或目录变化的场景:按文件名在密钥库目录下重找。
      final keysDir = await _keysDirectoryFuture;
      final fallback = File(
        '${keysDir.path}${Platform.pathSeparator}'
        '${file.uri.pathSegments.last}',
      );
      if (!await fallback.exists()) {
        return (privateKey: '', passphrase: '');
      }
      file = fallback;
    }
    final raw = await file.readAsString();
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic> && json['private_key'] is String) {
        return (
          privateKey: await _decryptField(json['private_key'] as String),
          passphrase: await _decryptField(json['passphrase'] as String? ?? ''),
        );
      }
    } on Object {
      // 非 JSON → 旧明文 PEM。
    }
    return (privateKey: raw, passphrase: '');
  }

  /// 解密存储字段;空串或明文(无前缀)原样返回,解密失败返回空串。
  Future<String> _decryptField(String value) async {
    if (value.isEmpty || !SecretsCipher.isEncrypted(value)) {
      return value;
    }
    try {
      return await _cipher.decrypt(value);
    } on Object catch (error, stackTrace) {
      AppLogger.e('密码字段解密失败', error, stackTrace);
      return '';
    }
  }

  /// 内存排序,对齐 SQLite 的排序语义。
  List<Device> _sorted(
    List<Device> devices,
    DeviceSortField sortField,
    SortDirection direction,
  ) {
    final multiplier = direction == SortDirection.descending ? -1 : 1;
    devices.sort((a, b) {
      var result = switch (sortField) {
        DeviceSortField.createdAt => a.createdAt.compareTo(b.createdAt),
        DeviceSortField.openCount => a.openCount.compareTo(b.openCount),
        DeviceSortField.lastConnectedAt => _compareNullable(
          a.lastConnectedAt,
          b.lastConnectedAt,
        ),
      };
      result *= multiplier;
      if (result != 0) {
        return result;
      }
      // 次级排序:会话名升序,与 SQLite 的 "name ASC" 一致。
      return a.name.compareTo(b.name);
    });
    return devices;
  }

  /// 可空整数比较:null 视为最小(升序排前,降序乘 -1 后排后)。
  int _compareNullable(int? a, int? b) {
    if (a == null && b == null) {
      return 0;
    }
    if (a == null) {
      return -1;
    }
    if (b == null) {
      return 1;
    }
    return a.compareTo(b);
  }
}
