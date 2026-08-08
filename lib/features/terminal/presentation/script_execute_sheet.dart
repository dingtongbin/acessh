// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../connection/application/terminal_session.dart';
import '../../script/application/script_controller.dart';
import '../../script/domain/app_script.dart';
import '../../script/domain/script_folder.dart';
import '../../script/presentation/script_edit_screen.dart';
import '../../script/presentation/script_name_dialog.dart';
import 'script_execute_confirm_dialog.dart';

/// 脚本执行底部弹出层:按文件夹层级浏览脚本,
/// 每条脚本提供执行按钮与三点菜单(展开才是编辑/删除)。
class ScriptExecuteSheet extends StatefulWidget {
  /// 创建脚本执行弹出层。
  const ScriptExecuteSheet({required this.session, super.key});

  /// 目标会话(脚本写入该会话的终端)。
  final TerminalSession session;

  @override
  State<ScriptExecuteSheet> createState() => _ScriptExecuteSheetState();
}

class _ScriptExecuteSheetState extends State<ScriptExecuteSheet> {
  bool _executing = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ScriptController>();
    final isEmpty = controller.folders.isEmpty && controller.scripts.isEmpty;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (controller.currentFolder.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 20),
                      tooltip: '返回上一级',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => controller.leaveFolder(),
                    ),
                  Expanded(
                    child: Text(
                      controller.currentFolderName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.create_new_folder_outlined,
                      size: 20,
                    ),
                    tooltip: '新建文件夹',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _createFolder(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 20),
                    tooltip: '新建脚本',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openScriptEditor(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (isEmpty)
              // 固定高度:内容少时也保持可用的操作区域。
              const SizedBox(height: 360, child: Center(child: Text('当前文件夹为空')))
            else
              SizedBox(
                height: 360,
                child: ListView.separated(
                  itemCount:
                      controller.folders.length + controller.scripts.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index < controller.folders.length) {
                      final folder = controller.folders[index];
                      return _FolderRow(
                        folder: folder,
                        onTap: () => controller.enterFolder(folder),
                        onAction: (action) =>
                            _handleFolderAction(context, folder, action),
                      );
                    }
                    final script =
                        controller.scripts[index - controller.folders.length];
                    return _ScriptRow(
                      script: script,
                      executing: _executing,
                      onExecute: () => _executeScript(script),
                      onAction: (action) =>
                          _handleScriptAction(context, script, action),
                    );
                  },
                ),
              ),
          ],
        ),
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
    if (name == null || !mounted) {
      return;
    }
    await controller.createFolder(name);
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

  /// 处理文件夹菜单动作(重命名/删除)。
  Future<void> _handleFolderAction(
    BuildContext context,
    ScriptFolder folder,
    String action,
  ) async {
    final controller = context.read<ScriptController>();
    switch (action) {
      case 'rename':
        final newName = await showDialog<String>(
          context: context,
          builder: (context) => ScriptNameDialog(
            title: '重命名文件夹',
            label: '文件夹名称',
            initialValue: folder.name,
          ),
        );
        if (newName == null || !mounted) {
          return;
        }
        await controller.renameFolder(folder, newName);
      case 'delete':
        final confirmed = await _confirmDelete(
          context,
          '删除文件夹"${folder.name}"',
          '将同时删除该文件夹下的全部脚本,此操作不可恢复。',
        );
        if (confirmed == true) {
          await controller.deleteFolder(folder);
        }
    }
  }

  /// 处理脚本菜单动作(编辑/重命名/删除)。
  Future<void> _handleScriptAction(
    BuildContext context,
    AppScript script,
    String action,
  ) async {
    final controller = context.read<ScriptController>();
    switch (action) {
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
        if (newName == null || !mounted) {
          return;
        }
        await controller.renameScript(script, newName);
      case 'delete':
        final confirmed = await _confirmDelete(
          context,
          '删除脚本"${script.name}"',
          '此操作不可恢复。',
        );
        if (confirmed == true) {
          await controller.deleteScript(script);
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

  /// 执行脚本:先弹出内容预览确认,确认后逐行写入会话终端并累计执行次数。
  Future<void> _executeScript(AppScript script) async {
    final controller = context.read<ScriptController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ScriptExecuteConfirmDialog(script: script),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _executing = true);
    try {
      await widget.session.sendScript(script.content);
      await controller.recordExecuted(script);
    } finally {
      if (mounted) {
        setState(() => _executing = false);
      }
    }
  }
}

/// 文件夹紧凑行。
class _FolderRow extends StatelessWidget {
  /// 创建文件夹行。
  const _FolderRow({
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
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Icon(Icons.folder, size: 20, color: scheme.primary),
      title: Text(folder.name, style: Theme.of(context).textTheme.bodyMedium),
      trailing: PopupMenuButton<String>(
        tooltip: '更多操作',
        onSelected: onAction,
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'rename',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.edit_outlined, size: 20),
              title: Text('重命名'),
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.delete_outline, size: 20, color: Colors.red),
              title: Text('删除'),
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// 脚本紧凑行:执行按钮 + 三点菜单。
class _ScriptRow extends StatelessWidget {
  /// 创建脚本行。
  const _ScriptRow({
    required this.script,
    required this.executing,
    required this.onExecute,
    required this.onAction,
  });

  /// 脚本数据。
  final AppScript script;

  /// 是否正在执行。
  final bool executing;

  /// 执行回调。
  final VoidCallback onExecute;

  /// 菜单动作回调。
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: const Icon(Icons.terminal, size: 20),
      title: Text(script.name, style: Theme.of(context).textTheme.bodyMedium),
      subtitle: Text(
        script.note.isNotEmpty ? script.note : '执行 ${script.executeCount} 次',
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: executing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow, size: 20),
            tooltip: '执行',
            visualDensity: VisualDensity.compact,
            onPressed: executing ? null : onExecute,
          ),
          PopupMenuButton<String>(
            tooltip: '更多操作',
            onSelected: onAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.edit_outlined, size: 20),
                  title: Text('编辑'),
                ),
              ),
              const PopupMenuItem(
                value: 'rename',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.drive_file_rename_outline, size: 20),
                  title: Text('重命名'),
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.red,
                  ),
                  title: Text('删除'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
