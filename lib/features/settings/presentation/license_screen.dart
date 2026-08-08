// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../core/paths/app_paths.dart';
import '../application/app_settings.dart';

/// 用户许可页:首次进入展示开源许可与隐私政策说明。
///
/// 必须手动勾选同意复选框(不默认勾选、不自动勾选),
/// 勾选后点击"同意并继续"即代表同意开源许可与用户隐私政策;未勾选无法继续。
class LicenseScreen extends StatefulWidget {
  /// 创建许可页。
  const LicenseScreen({this.onAccepted, super.key});

  /// 同意许可后的回调。
  final VoidCallback? onAccepted;

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  /// 是否已手动勾选同意(默认未勾选)。
  bool _agreed = false;

  /// 开源许可文本。
  static const String _licenseText =
      '欢迎使用 acessh\n\n'
      '本软件采用 AGPLv3.0 开源许可证。\n\n'
      '本软件绝不会收集用户的任何隐私和信息,'
      '所有数据均存储在用户设备本地。\n\n'
      '严格禁止任何商业行为,包括但不限于:销售、收费托管、'
      '广告变现等以本项目牟利的行为。\n\n'
      '严格禁止截取本项目源代码,在任何国家或地区注册软件著作权、'
      '专利等私自占有行为。\n\n'
      '对于违反上述规定者,无论公司还是个人,'
      '作者将绝对追究相应法律责任。';

  /// 隐私政策声明文本。
  static const String _privacyText =
      'acessh 隐私政策摘要\n\n'
      '本软件绝不收集、传输、上传任何个人信息与隐私数据。\n\n'
      '本地数据(仅存储于设备本地,卸载即删除):\n'
      '· 设备连接信息(主机/账号/密码/私钥/指纹)\n'
      '· 脚本与连接记录\n'
      '· 应用设置\n\n'
      '权限用途:网络(SSH/Telnet 连接)、文件(导入导出)、'
      '文件系统访问(保存数据到本地公共目录,卸载重装后保留)、'
      'USB(串口调试)。\n\n'
      '无广告、无统计、无推送、无第三方 SDK 上报。\n\n'
      '详细条款见应用内"开源许可与声明"。';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Icon(
                Icons.shield_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          _licenseText,
                          style: const TextStyle(height: 1.6),
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '用户隐私政策',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _showPrivacy(context),
                              child: const Text('查看全文'),
                            ),
                          ],
                        ),
                        SelectableText(
                          _privacyText,
                          style: const TextStyle(height: 1.6, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 必须手动勾选,不默认勾选。
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  '我已阅读并同意《开源许可与隐私政策》',
                  style: TextStyle(fontSize: 13),
                ),
                value: _agreed,
                onChanged: (value) {
                  setState(() => _agreed = value ?? false);
                },
              ),
              FilledButton(
                // 未勾选时无法继续。
                onPressed: _agreed
                    ? () async {
                        await context.read<AppSettings>().setLicenseAccepted();
                        // 同意许可后自动请求"所有文件访问"权限,
                        // 使数据存储在公共目录(卸载重装后保留)。
                        if (!await AppPaths.isPublicStorageAvailable()) {
                          await Permission.manageExternalStorage.request();
                        }
                        if (context.mounted) {
                          widget.onAccepted?.call();
                        }
                      }
                    : null,
                child: const Text('同意并继续'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => SystemNavigator.pop(),
                child: const Text('不同意,退出应用'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 查看隐私政策全文。
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
