# acessh

基于 [kterm](https://pub.dev/packages/kterm) 的移动端远程登录工具(SSH / Telnet / 串口),提供终端模拟与远程会话管理。

## 功能特性

- **多协议连接**:SSH(密码/私钥认证)、Telnet(自动检测 `login:` / `Password:` 提示并回填凭据)、串口
- **终端体验**:kterm 高速渲染、两排手机端快捷输入栏(ESC/Tab/方向键/Ctrl/Alt 修饰)、一键拉起/收起系统键盘
- **会话管理**:前台会话可后台挂起(连接保持),随时从"已连接"或后台会话列表切回
- **脚本**:脚本增删改查,执行前弹出内容预览确认,逐行写入终端
- **设备管理**:会话名为主键,记录打开次数与最近登录时间,支持按创建时间/打开次数/最近登录排序(正序/倒序),模糊搜索
- **私钥**:支持导入 OpenSSH PEM 私钥文件,或直接生成 Ed25519 密钥对
- **数据本地化**:全部数据(设备、脚本、连接记录、设置)存储于系统固定目录的 SQLite,不上传任何服务器

## 技术栈

| 组件 | 选型 | 说明 |
| --- | --- | --- |
| 终端模拟 | [kterm](https://pub.dev/packages/kterm) ^1.5.5 | 高性能终端模拟引擎 |
| SSH | [dartssh2](https://pub.dev/packages/dartssh2) ^2.22.5 | 纯 Dart SSH/SFTP 客户端 |
| Telnet | [ctelnet](https://pub.dev/packages/ctelnet) ^0.3.1 | Telnet 客户端,自动剥离 ANSI |
| 串口 | [flutter_libserialport](https://pub.dev/packages/flutter_libserialport) ^0.6.0 | 基于 libserialport |
| 数据库 | [sqflite](https://pub.dev/packages/sqflite) ^2.4.3 | SQLite |
| 密钥生成 | [cryptography](https://pub.dev/packages/cryptography) ^2.9.0 | Ed25519 密钥对生成 |
| 状态管理 | [provider](https://pub.dev/packages/provider) ^6.1.5 | 轻量稳定 |

## 快速开始

```bash
flutter pub get
flutter run          # 连接设备或模拟器运行
```

验证与质量检查(提交前必跑):

```bash
dart format .
flutter analyze      # 必须 0 error / 0 warning
flutter test         # 必须全绿
flutter build apk    # 或 flutter build windows 等按平台构建
```

## 目录结构

```
lib/
  main.dart                 # 入口,仅做引导
  app/                      # 应用级配置:路由、主题、全局初始化
  core/                     # 通用设施:数据库、日志、路径、常量、工具
  features/
    device/                 # 设备管理:模型、仓库、控制器与设备列表 UI
    connection/             # 连接:SSH/Telnet/串口会话、会话管理器、密钥服务
    terminal/               # 终端页:kterm 渲染、快捷栏、脚本执行、设置
    script/                 # 脚本:模型、仓库、控制器与编辑 UI
    settings/               # 应用设置(终端外观等)
    home/                   # 主页(搜索 + Tabs)
    shell/                  # 底部导航框架
    scripts_page/           # 底部导航"脚本"占位页
  shared/                   # 跨 feature 复用的组件
test/                       # 与 lib 对应的测试目录
```

## 常见问题

- **连接失败**:请确认目标主机端口可达、凭据正确;SSH 私钥需为 OpenSSH 格式(可先用 `ssh-keygen` 验证)。
- **测试环境**:测试服务器配置见 `test/test_servers_ssh.json` 与 `test/test_servers_telnet.json`。

## Logo 说明

本项目 Logo 来源于网络。如 Logo 存在任何侵权行为,请版权所有者联系作者(https://dingtongbin.cn/)并提供相关权利证明,作者将第一时间删除或更换。

## 参与贡献

请阅读 [CONTRIBUTING.md](CONTRIBUTING.md) 与 [CHANGELOG.md](CHANGELOG.md)。

## 许可证

[AGPLv3.0](LICENSE)

本项目采用 AGPLv3.0 开源许可证。**严格禁止任何商业行为**;
严格禁止截取源代码在任何国家或地区注册软件著作权等私自占有行为,
对于违反规定者,无论公司还是个人,作者将绝对追究相应法律责任。

- 作者博客:https://dingtongbin.cn/
- GitHub 主页:https://github.com/dingtongbin
- 项目仓库:https://github.com/dingtongbin/acessh
