// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/utils/date_formatter.dart';
import '../../connection/application/ssh_key_deployer.dart';
import '../../connection/application/ssh_key_service.dart';
import '../../connection/data/ssh_key_repository.dart';
import '../../connection/domain/stored_key.dart';

/// 全局密钥库选择面板:列出全部密钥供选择,支持新生成与删除。
///
/// 通过 `Navigator.pop(context, StoredKey)` 返回选中的密钥;
/// 面板内「生成新密钥」切换到生成视图,展示公钥文本便于分发到服务器。
class SshKeyPickerSheet extends StatefulWidget {
  /// 创建密钥选择面板;[repository] 供测试注入临时密钥目录。
  const SshKeyPickerSheet({this.repository, super.key});

  /// 密钥仓库,默认使用全局密钥库。
  final SshKeyRepository? repository;

  @override
  State<SshKeyPickerSheet> createState() => _SshKeyPickerSheetState();
}

class _SshKeyPickerSheetState extends State<SshKeyPickerSheet> {
  late final SshKeyRepository _repository;

  /// 密钥列表(实时读盘)。
  List<StoredKey>? _keys;

  /// 是否处于生成视图。
  bool _generatingView = false;

  /// 生成中的密钥。
  StoredKey? _generatedKey;

  /// 是否正在生成。
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SshKeyRepository();
    _loadKeys();
  }

  /// 从磁盘加载密钥列表。
  Future<void> _loadKeys() async {
    final keys = await _repository.listKeys();
    if (mounted) {
      setState(() => _keys = keys);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _generatingView ? '生成新密钥' : '选择密钥',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (_generatingView)
                  TextButton(
                    onPressed: () => setState(() {
                      _generatingView = false;
                      _generatedKey = null;
                    }),
                    child: const Text('返回列表'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_generatingView)
              _buildGenerateView(context)
            else
              _buildListView(context),
          ],
        ),
      ),
    );
  }

  /// 密钥列表视图。
  Widget _buildListView(BuildContext context) {
    final keys = _keys;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: keys == null
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : keys.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '密钥库为空,可生成或导入密钥',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: keys.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final key = keys[index];
                    return ListTile(
                      leading: const Icon(Icons.vpn_key_outlined),
                      title: Text(key.name),
                      subtitle: Text(
                        '${key.passphrase.isEmpty ? '无口令' : '加密密钥'} · '
                        '创建于 ${DateFormatter.formatMillis(key.createdAt)}',
                      ),
                      onTap: () => Navigator.of(context).pop(key),
                      onLongPress: () => _showKeyActions(context, key),
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.add),
          label: const Text('生成新密钥'),
          onPressed: () => setState(() {
            _generatingView = true;
            _generatedKey = null;
          }),
        ),
      ],
    );
  }

  /// 生成视图:生成 Ed25519 密钥,展示公钥供复制分发到服务器。
  Widget _buildGenerateView(BuildContext context) {
    final key = _generatedKey;
    if (key == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '生成后请将公钥添加到服务器的 ~/.ssh/authorized_keys',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: _generating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high),
            label: Text(_generating ? '生成中' : '生成 Ed25519 密钥'),
            onPressed: _generating ? null : _generateKey,
          ),
        ],
      );
    }
    String publicKey;
    try {
      publicKey = SshKeyService.derivePublicKey(key.privateKey);
    } on Object catch (error, stackTrace) {
      AppLogger.e('推导公钥失败', error, stackTrace);
      publicKey = '公钥推导失败:$error';
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.vpn_key),
          title: Text(key.name),
          subtitle: Text('创建于 ${DateFormatter.formatMillis(key.createdAt)}'),
        ),
        const SizedBox(height: 8),
        Text(
          '公钥(添加到服务器 authorized_keys):',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            publicKey,
            style: const TextStyle(fontSize: 11),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('复制公钥'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: publicKey));
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('公钥已复制')));
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: const Text('使用此密钥'),
                onPressed: () => Navigator.of(context).pop(key),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.cloud_upload_outlined, size: 18),
          label: const Text('部署到服务器(ssh-copy)'),
          onPressed: () => _deployWithPublicKey(context, publicKey),
        ),
      ],
    );
  }

  /// 生成 Ed25519 密钥并入库。
  Future<void> _generateKey() async {
    setState(() => _generating = true);
    try {
      final pem = await SshKeyService.generateEd25519();
      final key = await _repository.createKey(privateKey: pem);
      if (mounted) {
        setState(() {
          _generatedKey = key;
          _generating = false;
        });
      }
    } on Object catch (error, stackTrace) {
      AppLogger.e('生成密钥失败', error, stackTrace);
      if (mounted) {
        setState(() => _generating = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('生成密钥失败:$error')));
      }
    }
  }

  /// 长按删除密钥的确认对话框。
  Future<void> _confirmDelete(BuildContext context, StoredKey key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除密钥'),
        content: Text(
          '确定删除密钥"${key.name}"吗?\n'
          '引用该密钥的设备将无法再连接。',
        ),
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
    if (confirmed != true || !context.mounted) {
      return;
    }
    await _repository.deleteKey(key.name);
    await _loadKeys();
  }

  /// 长按密钥弹出操作面板:部署到服务器 / 删除。
  Future<void> _showKeyActions(BuildContext context, StoredKey key) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                key.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '创建于 ${DateFormatter.formatMillis(key.createdAt)}'
                '${key.passphrase.isEmpty ? '' : ' · 加密密钥'}',
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: const Text('部署到服务器'),
              onTap: () => Navigator.of(sheetContext).pop('deploy'),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除'),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) {
      return;
    }
    switch (action) {
      case 'deploy':
        await _deployKey(context, key);
      case 'delete':
        await _confirmDelete(context, key);
    }
  }

  /// 弹出"部署到服务器"对话框,成功后提示可用密钥登录。
  Future<void> _deployWithPublicKey(
    BuildContext context,
    String publicKey,
  ) async {
    final deployed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeployKeyDialog(publicKey: publicKey),
    );
    if (deployed == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('公钥已部署,现在可以用密钥登录了')));
    }
  }

  /// 弹出"部署到服务器"对话框(从密钥记录推导公钥)。
  Future<void> _deployKey(BuildContext context, StoredKey key) async {
    final String publicKey;
    try {
      publicKey = SshKeyService.derivePublicKey(key.privateKey);
    } on Object catch (error, stackTrace) {
      AppLogger.e('推导公钥失败', error, stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('公钥推导失败:$error')));
      }
      return;
    }
    await _deployWithPublicKey(context, publicKey);
  }
}

/// 公钥部署对话框:输入服务器地址与账户密码,用密码登录后把公钥
/// 追加到 `~/.ssh/authorized_keys`(等价 ssh-copy-id)。
class _DeployKeyDialog extends StatefulWidget {
  /// 创建部署对话框。
  const _DeployKeyDialog({required this.publicKey});

  /// 要部署的 authorized_keys 公钥行。
  final String publicKey;

  @override
  State<_DeployKeyDialog> createState() => _DeployKeyDialogState();
}

class _DeployKeyDialogState extends State<_DeployKeyDialog> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _deploying = false;
  String? _errorText;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('部署公钥到服务器'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '使用密码登录服务器,把公钥追加到 ~/.ssh/authorized_keys,'
              '之后即可用密钥登录。',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: '主机地址',
                hintText: '如 192.168.0.1',
                prefixIcon: Icon(Icons.dns_outlined),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: '端口',
                prefixIcon: Icon(Icons.numbers),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '账户',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: '密码',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _deploying ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _deploying ? null : _deploy,
          child: Text(_deploying ? '部署中…' : '部署'),
        ),
      ],
    );
  }

  /// 校验输入并执行部署。
  Future<void> _deploy() async {
    final host = _hostController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (host.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() => _errorText = '请填写主机、账户与密码');
      return;
    }
    setState(() {
      _errorText = null;
      _deploying = true;
    });
    try {
      await SshKeyDeployer.deploy(
        host: host,
        port: int.tryParse(_portController.text.trim()) ?? 22,
        username: username,
        password: password,
        publicKey: widget.publicKey,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on SSHAuthFailError {
      if (mounted) {
        setState(() {
          _deploying = false;
          _errorText = '账户或密码错误,请检查后重试';
        });
      }
    } on Object catch (error, stackTrace) {
      AppLogger.e('部署公钥失败', error, stackTrace);
      if (mounted) {
        setState(() {
          _deploying = false;
          _errorText = '部署失败:$error';
        });
      }
    }
  }
}
