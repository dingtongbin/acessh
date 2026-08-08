// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import '../domain/device.dart';
import '../domain/device_sort_field.dart';

/// 设备过滤与排序的纯函数,便于单元测试。
abstract final class DeviceSorter {
  const DeviceSorter._();

  /// 按关键字过滤(会话名/主机/用户名,不区分大小写)并按规则排序。
  static List<Device> filterAndSort({
    required List<Device> devices,
    required String keyword,
    required DeviceSortField sortField,
    required SortDirection direction,
  }) {
    final trimmed = keyword.trim().toLowerCase();
    final result = trimmed.isEmpty
        ? List<Device>.of(devices)
        : devices.where((device) => _matches(device, trimmed)).toList();
    result.sort((a, b) {
      final compare = switch (sortField) {
        DeviceSortField.createdAt => a.createdAt.compareTo(b.createdAt),
        DeviceSortField.openCount => a.openCount.compareTo(b.openCount),
        DeviceSortField.lastConnectedAt => _lastConnectedRank(
          a.lastConnectedAt,
          direction,
        ).compareTo(_lastConnectedRank(b.lastConnectedAt, direction)),
      };
      return direction == SortDirection.descending ? -compare : compare;
    });
    return result;
  }

  /// 未登录过(null)的设备在正序时视为最大、倒序时视为最小,始终排在最后。
  static int _lastConnectedRank(int? millis, SortDirection direction) {
    if (millis != null) {
      return millis;
    }
    return direction == SortDirection.descending ? -1 : 0x7FFFFFFFFFFFFFFF;
  }

  /// 设备是否命中关键字。
  static bool _matches(Device device, String keyword) {
    return device.name.toLowerCase().contains(keyword) ||
        device.host.toLowerCase().contains(keyword) ||
        device.username.toLowerCase().contains(keyword);
  }
}
