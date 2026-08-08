# 贡献指南

感谢您对 acessh 的关注与贡献。请先阅读本指南,再发起 Issue 或 Pull Request。

## 开发环境

- Flutter 3.44+(Dart 3.12+)
- 代码规范见 [AGENTS.md](AGENTS.md)(opencode 自动注入,人工开发同样遵循)

## 提交前检查(必跑)

```bash
dart format .
flutter analyze   # 0 error、0 warning
flutter test      # 全绿
```

## 提交信息

遵循 [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>
```

- type:`feat` / `fix` / `docs` / `style` / `refactor` / `perf` / `test` / `build` / `ci` / `chore` / `revert`
- scope:受影响模块名(如 `device`、`connection`、`terminal`、`script`)
- subject:祈使句、小写开头、不超过 72 字符、不加句号

## 分支与 PR

- 功能分支:`feature/<简短描述>`;修复分支:`fix/<简短描述>`
- 禁止直接向 `main` 推送
- PR 描述需说明动机、改动与验证方式
- 行为变更必须同步更新 [CHANGELOG.md](CHANGELOG.md)

## 代码要求

- 新增依赖前在 PR 描述中说明用途,优先选择活跃维护、API 稳定的包
- 分层依赖单向:UI → 应用逻辑 → 领域 → 数据,禁止反向依赖
- 非平凡逻辑必须补充单元测试(正常 + 错误 + 边界路径)
- 禁止提交敏感信息(token、密钥、密码、个人路径)

## 敏感信息

- 测试服务器凭据不得写入代码与配置文件,请通过环境变量或本地未跟踪配置注入
- 禁止提交任何 `.db`、私钥、日志等敏感产物
