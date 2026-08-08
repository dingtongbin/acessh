// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/paths/app_paths.dart';
import '../application/app_settings.dart';
import 'app_lock_settings_screen.dart';
import 'terminal_settings_screen.dart';

/// 作者博客。
const String kAuthorBlogUrl = 'https://dingtongbin.cn/';

/// 项目 GitHub 仓库。
const String kProjectGithubUrl = 'https://github.com/dingtongbin/acessh';

/// QQ 交流群号。
const String kQqGroupNumber = '1075801515';

/// 可选的应用主题色。
const List<Color> kThemeColors = [
  Color(0xFF006A6A), // 青绿(默认)
  Color(0xFF1565C0), // 蓝
  Color(0xFF1E88E5), // 亮蓝
  Color(0xFF6A1B9A), // 紫
  Color(0xFFAD1457), // 玫红
  Color(0xFFC62828), // 红
  Color(0xFFEF6C00), // 橙
  Color(0xFF2E7D32), // 绿
  Color(0xFF00838F), // 青
  Color(0xFF37474F), // 蓝灰
];

/// 设置页:开源许可(置顶)、主题、终端、应用锁与关于信息。
class SettingsScreen extends StatelessWidget {
  /// 创建设置页。
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // 开源许可置顶显示。
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('开源许可与声明'),
            subtitle: const Text('AGPLv3.0 · 禁止商业与盗版'),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => _showLicense(context),
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: const Icon(Icons.palette_outlined),
            title: const Text('主题设置'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 紧凑矮下拉:主题模式。
                _CompactDropdown<AppThemeMode>(
                  value: settings.themeMode,
                  items: const [
                    (AppThemeMode.system, '跟随系统'),
                    (AppThemeMode.light, '浅色'),
                    (AppThemeMode.dark, '深色'),
                  ],
                  onChanged: (value) => settings.setThemeMode(value),
                ),
                const SizedBox(height: 4),
                // 紧凑矮下拉:主题颜色。
                _CompactDropdown<Color>(
                  value: settings.themeColor,
                  items: [
                    for (final color in kThemeColors)
                      (color, _colorName(color)),
                  ],
                  leading: (color) => _ColorPreview(color: color),
                  onChanged: (value) => settings.setThemeColor(value),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: const Icon(Icons.terminal),
            title: const Text('终端设置'),
            subtitle: const Text('主题、字体、颜色、背景与选择行为'),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const TerminalSettingsScreen(),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: const Icon(Icons.lock_outline),
            title: const Text('应用锁设置'),
            subtitle: Text(settings.appLockEnabled ? '已开启' : '未开启'),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const AppLockSettingsScreen(),
              ),
            ),
          ),
          const Divider(height: 1),
          _StorageTile(),
          const Divider(height: 1),
          _SectionHeader('关于'),
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: const Icon(Icons.person_outline),
            title: const Text('联系作者'),
            subtitle: const Text(kAuthorBlogUrl),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _launch(context, kAuthorBlogUrl),
          ),
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: const Icon(Icons.folder_outlined),
            title: const Text('项目仓库'),
            subtitle: const Text(kProjectGithubUrl),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _launch(context, kProjectGithubUrl),
          ),
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: const Icon(Icons.groups_outlined),
            title: const Text('加入 QQ 交流群'),
            subtitle: const Text('群号 $kQqGroupNumber(点击复制)'),
            trailing: const Icon(Icons.copy, size: 18),
            onTap: () => _copyQqGroup(context),
          ),
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: const Icon(Icons.info_outline),
            title: const Text('关于'),
            subtitle: const Text('acessh 0.1.0 · 移动端远程登录工具'),
            onTap: () => _showAbout(context),
          ),
        ],
      ),
    );
  }

  /// 打开外部链接。
  Future<void> _launch(BuildContext context, String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法打开链接:$url')));
    }
  }

  /// 复制 QQ 群号并尝试拉起 QQ 群卡片。
  Future<void> _copyQqGroup(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: kQqGroupNumber));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QQ 群号 $kQqGroupNumber 已复制,打开 QQ 搜索加入')),
    );
    // 拉起 QQ 群卡片(card_type=group 指定跳转群而非用户,未安装 QQ 时静默失败)。
    await launchUrl(
      Uri.parse(
        'mqqapi://card/show_pslcard?src_type=internal&version=1'
        '&uin=$kQqGroupNumber&card_type=group&source=qrcode',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  /// 关于信息。
  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关于 acessh'),
        content: const Text(
          'acessh v0.1.0\n\n'
          '基于 Flutter 的移动端远程登录工具,\n'
          '支持 SSH / Telnet / 串口连接,\n'
          '提供终端模拟、脚本管理与会话管理。\n\n'
          '本软件绝不会收集用户的任何隐私和信息。\n\n'
          'Logo 来源于网络,如存在侵权行为,\n'
          '请版权所有者联系作者删除。\n\n'
          '作者:丁同斌\n'
          '博客:https://dingtongbin.cn/',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 开源许可与声明。
  void _showLicense(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('开源许可与声明'),
        content: const SingleChildScrollView(
          child: Text(
            '本项目采用 AGPLv3.0 开源许可证。\n\n'
            '本软件绝不会收集用户的任何隐私和信息,'
            '所有数据均存储在用户设备本地。\n\n'
            '严格禁止任何商业行为,包括但不限于:销售、收费托管、'
            '广告变现等以本项目牟利的行为。\n\n'
            '严格禁止截取本项目源代码,在任何国家或地区注册软件著作权、'
            '专利等私自占有行为。\n\n'
            '对于违反上述规定者,无论公司还是个人,'
            '作者将绝对追究相应法律责任。\n\n'
            '项目地址:https://github.com/dingtongbin/acessh',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () => _showPrivacy(context),
            child: const Text('隐私政策'),
          ),
        ],
      ),
    );
  }

  /// 隐私政策弹窗。
  void _showPrivacy(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('用户隐私政策'),
        content: const SingleChildScrollView(
          child: Text(
            'acessh 绝不收集、传输、上传任何个人信息与隐私数据。\n\n'
            '一、数据说明\n'
            '全部数据(设备连接信息、脚本、连接记录、设置)'
            '仅存储于设备本地应用目录,卸载即删除,不上传任何服务器。\n\n'
            '二、权限说明\n'
            '· 网络:SSH/Telnet 远程连接\n'
            '· 文件:导入导出脚本/密钥/背景图片\n'
            '· 文件系统访问:保存数据到本地公共目录,卸载重装后保留\n'
            '· USB:串口调试\n\n'
            '三、第三方\n'
            '无广告、无统计、无推送、无第三方 SDK 数据上报。\n'
            '仅有的外部链接为开发者博客与开源仓库,由用户主动点击。\n\n'
            '四、联系方式\n'
            '博客:https://dingtongbin.cn/\n'
            '仓库:https://github.com/dingtongbin/acessh',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

/// 数据存储设置:显示存储位置,未授权时引导开启"所有文件访问"。
class _StorageTile extends StatefulWidget {
  /// 创建存储设置项。
  const _StorageTile();

  @override
  State<_StorageTile> createState() => _StorageTileState();
}

class _StorageTileState extends State<_StorageTile> {
  bool? _publicAvailable;

  @override
  void initState() {
    super.initState();
    _check();
  }

  /// 检查公共存储是否可用。
  Future<void> _check() async {
    final available = await AppPaths.isPublicStorageAvailable();
    if (mounted) {
      setState(() => _publicAvailable = available);
    }
  }

  /// 请求"所有文件访问"权限(Android 11+ 跳转系统设置页)。
  Future<void> _grantAccess() async {
    final status = await Permission.manageExternalStorage.request();
    if (!mounted) {
      return;
    }
    if (status.isGranted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('权限已授予,请重启应用以切换到公共存储目录')));
      await _check();
    } else if (status.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未授予权限,数据将存储在应用内部目录')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _publicAvailable;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: const Icon(Icons.storage_outlined),
      title: const Text('数据存储'),
      subtitle: Text(
        available == null
            ? '检测中...'
            : available
            ? '/storage/emulated/0/acessh(卸载后保留)'
            : '应用内部目录(卸载将清除数据)',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: available == false
          ? TextButton(onPressed: _grantAccess, child: const Text('开启持久化'))
          : null,
      onTap: available == false ? _grantAccess : null,
    );
  }
}

/// 主题色名称。
String _colorName(Color color) {
  const names = <int, String>{
    0xFF006A6A: '青绿',
    0xFF1565C0: '蓝',
    0xFF1E88E5: '亮蓝',
    0xFF6A1B9A: '紫',
    0xFFAD1457: '玫红',
    0xFFC62828: '红',
    0xFFEF6C00: '橙',
    0xFF2E7D32: '绿',
    0xFF00838F: '青',
    0xFF37474F: '蓝灰',
  };
  return names[color.toARGB32()] ?? '自定义';
}

/// 紧凑矮下拉选择器(无边框、小高度,适配设置列表)。
class _CompactDropdown<T> extends StatelessWidget {
  /// 创建紧凑下拉。
  const _CompactDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    this.leading,
  });

  /// 当前值。
  final T value;

  /// 选项列表(值与显示文本)。
  final List<(T, String)> items;

  /// 变更回调。
  final ValueChanged<T> onChanged;

  /// 可选的选项前置组件(如色块)。
  final Widget Function(T)? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          iconSize: 16,
          style: Theme.of(context).textTheme.bodyMedium,
          items: [
            for (final (itemValue, label) in items)
              DropdownMenuItem<T>(
                value: itemValue,
                child: Row(
                  children: [
                    if (leading != null) ...[
                      leading!(itemValue),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (selected) {
            if (selected != null) {
              onChanged(selected);
            }
          },
        ),
      ),
    );
  }
}

/// 颜色预览小色块。
class _ColorPreview extends StatelessWidget {
  /// 创建色块。
  const _ColorPreview({required this.color});

  /// 颜色值。
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    );
  }
}

/// 设置分组标题。
class _SectionHeader extends StatelessWidget {
  /// 创建分组标题。
  const _SectionHeader(this.title);

  /// 标题文本。
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// 主题色选择圆点。
