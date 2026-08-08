// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

/// 设备列表排序字段。
enum DeviceSortField {
  /// 按创建时间排序。
  createdAt,

  /// 按打开次数排序。
  openCount,

  /// 按最近登录时间排序。
  lastConnectedAt;

  /// 界面展示名。
  String get displayName => switch (this) {
    DeviceSortField.createdAt => '创建时间',
    DeviceSortField.openCount => '打开次数',
    DeviceSortField.lastConnectedAt => '最近登录',
  };
}

/// 排序方向。
enum SortDirection {
  /// 正序(升序)。
  ascending,

  /// 倒序(降序)。
  descending;

  /// 界面展示名。
  String get displayName => switch (this) {
    SortDirection.ascending => '正序',
    SortDirection.descending => '倒序',
  };
}
