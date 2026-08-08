// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/utils/date_formatter.dart';
import '../application/script_controller.dart';
import '../domain/app_script.dart';
import '../domain/script_folder.dart';
import 'script_edit_screen.dart';
import 'script_exporter.dart';
import 'script_import.dart';
import 'script_name_dialog.dart';

/// 底部导航"脚本"页:按文件夹层级管理脚本,支持文件夹与脚本的增删改查。
class ScriptsScreen extends StatelessWidget {
  /// 创建脚本页。
  const ScriptsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ScriptController>();
    final isEmpty = controller.folders.isEmpty && controller.scripts.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(controller.currentFolderName),
        leading: controller.currentFolder.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: '返回上一级',
                onPressed: () => controller.leaveFolder(),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: '导入脚本',
            onPressed: () => importScript(context),
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: '新建文件夹',
            onPressed: () => _createFolder(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建脚本',
            onPressed: () => _openScriptEditor(context),
          ),
        ],
      ),
      body: isEmpty
          ? const _EmptyScriptState()
          : ListView.separated(
              itemCount: controller.folders.length + controller.scripts.length,
              separatorBuilder: (_, _) =>
                  const Divider(indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                if (index < controller.folders.length) {
                  final folder = controller.folders[index];
                  return _FolderTile(
                    folder: folder,
                    onTap: () => controller.enterFolder(folder),
                    onAction: (action) =>
                        _handleFolderAction(context, folder, action),
                  );
                }
                final script =
                    controller.scripts[index - controller.folders.length];
                return _ScriptTile(
                  script: script,
                  onAction: (action) =>
                      _handleScriptAction(context, script, action),
                );
              },
            ),
    );
  }

  /// 弹出新建文件夹对话框。
  Future<void> _createFolder(BuildContext context) async {
    final controller = context.read<ScriptController>();
    final name = await showDialog<String>(
      context: context,
      builder: (context) =>
          const ScriptNameDialog(title: '新建文件夹', label: '文件夹名称'),
    );
    if (name == null || !context.mounted) {
      return;
    }
    try {
      await controller.createFolder(name);
    } on Object catch (error, stackTrace) {
      AppLogger.e('新建文件夹失败', error, stackTrace);
      if (context.mounted) {
        _showError(context, '新建文件夹失败:$error');
      }
    }
  }

  /// 打开脚本编辑页(新建)。
  Future<void> _openScriptEditor(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const ScriptEditScreen()),
    );
  }

  /// 打开脚本编辑页(编辑)。
  Future<void> _openScriptEditorFor(BuildContext context, AppScript script) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ScriptEditScreen(script: script),
      ),
    );
  }

  /// 处理文件夹菜单动作。
  Future<void> _handleFolderAction(
    BuildContext context,
    ScriptFolder folder,
    String action,
  ) async {
    final controller = context.read<ScriptController>();
    switch (action) {
      case 'export':
        try {
          await ScriptExporter.exportFolder(folder);
        } on Object catch (error, stackTrace) {
          AppLogger.e('导出文件夹失败', error, stackTrace);
          if (context.mounted) {
            _showError(context, '导出失败:$error');
          }
        }
      case 'rename':
        final newName = await showDialog<String>(
          context: context,
          builder: (context) => ScriptNameDialog(
            title: '重命名文件夹',
            label: '文件夹名称',
            initialValue: folder.name,
          ),
        );
        if (newName == null || !context.mounted) {
          return;
        }
        try {
          await controller.renameFolder(folder, newName);
        } on Object catch (error, stackTrace) {
          AppLogger.e('重命名文件夹失败', error, stackTrace);
          if (context.mounted) {
            _showError(context, '重命名失败:$error');
          }
        }
      case 'delete':
        final confirmed = await _confirmDelete(
          context,
          '删除文件夹"${folder.name}"',
          '将同时删除该文件夹下的全部脚本,此操作不可恢复。',
        );
        if (confirmed != true || !context.mounted) {
          return;
        }
        try {
          await controller.deleteFolder(folder);
        } on Object catch (error, stackTrace) {
          AppLogger.e('删除文件夹失败', error, stackTrace);
          if (context.mounted) {
            _showError(context, '删除失败:$error');
          }
        }
    }
  }

  /// 处理脚本菜单动作。
  Future<void> _handleScriptAction(
    BuildContext context,
    AppScript script,
    String action,
  ) async {
    final controller = context.read<ScriptController>();
    switch (action) {
      case 'export':
        try {
          await ScriptExporter.exportScript(script);
        } on Object catch (error, stackTrace) {
          AppLogger.e('导出脚本失败', error, stackTrace);
          if (context.mounted) {
            _showError(context, '导出失败:$error');
          }
        }
      case 'edit':
        await _openScriptEditorFor(context, script);
      case 'rename':
        final newName = await showDialog<String>(
          context: context,
          builder: (context) => ScriptNameDialog(
            title: '重命名脚本',
            label: '脚本名称',
            initialValue: script.name,
          ),
        );
        if (newName == null || !context.mounted) {
          return;
        }
        try {
          await controller.renameScript(script, newName);
        } on Object catch (error, stackTrace) {
          AppLogger.e('重命名脚本失败', error, stackTrace);
          if (context.mounted) {
            _showError(context, '重命名失败:$error');
          }
        }
      case 'delete':
        final confirmed = await _confirmDelete(
          context,
          '删除脚本"${script.name}"',
          '此操作不可恢复。',
        );
        if (confirmed != true || !context.mounted) {
          return;
        }
        try {
          await controller.deleteScript(script);
        } on Object catch (error, stackTrace) {
          AppLogger.e('删除脚本失败', error, stackTrace);
          if (context.mounted) {
            _showError(context, '删除失败:$error');
          }
        }
    }
  }

  /// 弹窗确认删除。
  Future<bool?> _confirmDelete(
    BuildContext context,
    String title,
    String message,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 展示错误提示。
  void _showError(BuildContext context, String message) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// 脚本文件夹条目。
class _FolderTile extends StatelessWidget {
  /// 创建文件夹条目。
  const _FolderTile({
    required this.folder,
    required this.onTap,
    required this.onAction,
  });

  /// 文件夹数据。
  final ScriptFolder folder;

  /// 点击回调。
  final VoidCallback onTap;

  /// 菜单动作回调。
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(Icons.folder, color: scheme.primary),
      title: Text(folder.name),
      trailing: PopupMenuButton<String>(
        onSelected: onAction,
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'rename',
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('重命名'),
            ),
          ),
          const PopupMenuItem(
            value: 'export',
            child: ListTile(
              leading: Icon(Icons.file_download_outlined),
              title: Text('导出'),
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red),
              title: Text('删除'),
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// 脚本条目。
class _ScriptTile extends StatelessWidget {
  /// 创建脚本条目。
  const _ScriptTile({required this.script, required this.onAction});

  /// 脚本数据。
  final AppScript script;

  /// 菜单动作回调。
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.terminal),
      title: Text(script.name),
      subtitle: Text(
        script.note.isNotEmpty
            ? '${script.note} · 执行 ${script.executeCount} 次 · '
                  '更新于 ${DateFormatter.formatMillis(script.updatedAt)}'
            : '执行 ${script.executeCount} 次 · '
                  '更新于 ${DateFormatter.formatMillis(script.updatedAt)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<String>(
        onSelected: onAction,
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('编辑'),
            ),
          ),
          const PopupMenuItem(
            value: 'rename',
            child: ListTile(
              leading: Icon(Icons.drive_file_rename_outline),
              title: Text('重命名'),
            ),
          ),
          const PopupMenuItem(
            value: 'export',
            child: ListTile(
              leading: Icon(Icons.file_download_outlined),
              title: Text('导出'),
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red),
              title: Text('删除'),
            ),
          ),
        ],
      ),
      onTap: () => onAction('edit'),
    );
  }
}

/// 脚本列表为空时的提示。
class _EmptyScriptState extends StatelessWidget {
  /// 创建空状态。
  const _EmptyScriptState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            '当前文件夹为空,可新建文件夹或脚本',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
