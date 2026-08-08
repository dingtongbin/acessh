// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:io';

import 'package:acessh/features/script/data/script_file_repository.dart';
import 'package:acessh/features/script/domain/app_script.dart';
import 'package:flutter_test/flutter_test.dart';

AppScript buildScript({
  String name = '部署脚本',
  String content = 'ls -la\necho done',
  String note = '生产环境部署',
  String folderPath = '',
}) {
  return AppScript(
    name: name,
    content: content,
    note: note,
    folderPath: folderPath,
    createdAt: 1,
    updatedAt: 1,
    executeCount: 0,
  );
}

void main() {
  late Directory root;
  late ScriptFileRepository repository;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('acessh_scripts_test_');
    repository = ScriptFileRepository(root: root);
  });

  tearDown(() async {
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
  });

  group('ScriptFileRepository 脚本 CRUD', () {
    test('保存后可在根目录列出,内容/备注/次数完整', () async {
      await repository.saveScript(buildScript());
      final scripts = await repository.listScripts('');
      expect(scripts, hasLength(1));
      expect(scripts.single.name, '部署脚本');
      expect(scripts.single.content, 'ls -la\necho done');
      expect(scripts.single.note, '生产环境部署');
      expect(scripts.single.executeCount, 0);
    });

    test('同名脚本重复保存抛异常', () async {
      await repository.saveScript(buildScript());
      await expectLater(
        repository.saveScript(buildScript()),
        throwsA(isA<StateError>()),
      );
    });

    test('更新脚本内容与备注', () async {
      await repository.saveScript(buildScript());
      final script = (await repository.listScripts('')).single;
      await repository.updateScript(
        script.copyWith(content: 'uptime', note: '新备注'),
      );
      final updated = (await repository.listScripts('')).single;
      expect(updated.content, 'uptime');
      expect(updated.note, '新备注');
    });

    test('重命名脚本会更新文件名与内部 name 字段', () async {
      await repository.saveScript(buildScript());
      await repository.renameScript('', '部署脚本', '新名字');
      final scripts = await repository.listScripts('');
      expect(scripts.single.name, '新名字');
      expect(File('${root.path}/新名字.json').existsSync(), isTrue);
      expect(File('${root.path}/部署脚本.json').existsSync(), isFalse);
    });

    test('重命名为已存在的名字抛异常', () async {
      await repository.saveScript(buildScript());
      await repository.saveScript(buildScript(name: '另一个'));
      await expectLater(
        repository.renameScript('', '部署脚本', '另一个'),
        throwsA(isA<StateError>()),
      );
    });

    test('删除脚本', () async {
      await repository.saveScript(buildScript());
      await repository.deleteScript('', '部署脚本');
      expect(await repository.listScripts(''), isEmpty);
    });

    test('recordExecuted 使执行次数 +1', () async {
      await repository.saveScript(buildScript());
      final script = (await repository.listScripts('')).single;
      await repository.recordExecuted(script);
      final recorded = (await repository.listScripts('')).single;
      expect(recorded.executeCount, 1);
      await repository.recordExecuted(recorded);
      expect((await repository.listScripts('')).single.executeCount, 2);
    });
  });

  group('ScriptFileRepository 文件夹', () {
    test('新建/列出/重命名/删除文件夹', () async {
      await repository.createFolder('', '运维');
      await repository.createFolder('', '部署');
      var folders = await repository.listFolders('');
      expect(folders.map((f) => f.name).toList(), ['运维', '部署']);

      await repository.renameFolder('', '运维', '生产运维');
      folders = await repository.listFolders('');
      expect(folders.map((f) => f.name).toList(), ['生产运维', '部署']);

      await repository.deleteFolder('', '部署');
      folders = await repository.listFolders('');
      expect(folders.map((f) => f.name).toList(), ['生产运维']);
    });

    test('重名文件夹抛异常', () async {
      await repository.createFolder('', '运维');
      await expectLater(
        repository.createFolder('', '运维'),
        throwsA(isA<StateError>()),
      );
    });

    test('删除文件夹递归删除其中脚本', () async {
      await repository.createFolder('', '运维');
      await repository.saveScript(buildScript(folderPath: '运维'));
      await repository.deleteFolder('', '运维');
      expect(await repository.listFolders(''), isEmpty);
      expect(Directory('${root.path}/运维').existsSync(), isFalse);
    });

    test('嵌套文件夹层级', () async {
      await repository.createFolder('', '一级');
      await repository.createFolder('一级', '二级');
      await repository.saveScript(buildScript(folderPath: '一级/二级'));

      expect((await repository.listFolders('')).single.name, '一级');
      expect((await repository.listFolders('一级')).single.name, '二级');
      final scripts = await repository.listScripts('一级/二级');
      expect(scripts.single.folderPath, '一级/二级');
    });
  });

  group('ScriptFileRepository 输入校验', () {
    test('拒绝非法路径穿越', () async {
      await expectLater(
        repository.saveScript(buildScript(folderPath: '../hack')),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        repository.listScripts('../hack'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('拒绝非法名称', () async {
      await expectLater(
        repository.createFolder('', 'a/b'),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        repository.saveScript(buildScript(name: '..')),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('不存在的文件夹列表报错', () async {
      await expectLater(
        repository.listScripts('不存在'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
