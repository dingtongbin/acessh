# Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
# SPDX-License-Identifier: AGPL-3.0-only

# acessh Android 构建辅助脚本。
# 显式指定缓存与 SDK 目录到 D 盘,避免占用 C 盘空间;
# 与用户级环境变量(GRADLE_USER_HOME / ANDROID_HOME / PUB_CACHE)保持一致。
$ErrorActionPreference = 'Stop'

$env:GRADLE_USER_HOME = 'D:\tools\gradle-home'
$env:ANDROID_HOME = 'D:\tools\android-sdk'
$env:ANDROID_SDK_ROOT = 'D:\tools\android-sdk'
$env:PUB_CACHE = 'D:\tools\pub-cache'

if ($args.Count -eq 0) {
    flutter build apk --debug
} else {
    flutter @args
}
