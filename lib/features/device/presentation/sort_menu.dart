// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import '../domain/device_sort_field.dart';

/// 排序控件:展示当前排序字段,点击弹出字段选择与方向切换菜单。
class SortMenu extends StatelessWidget {
  /// 创建排序菜单。
  const SortMenu({
    required this.field,
    required this.direction,
    required this.onChanged,
    super.key,
  });

  /// 当前排序字段。
  final DeviceSortField field;

  /// 当前排序方向。
  final SortDirection direction;

  /// 排序变更回调。
  final void Function(DeviceSortField field, SortDirection direction) onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DeviceSortField>(
      tooltip: '排序',
      onSelected: (selected) {
        final nextDirection = selected == field
            ? direction == SortDirection.ascending
                  ? SortDirection.descending
                  : SortDirection.ascending
            : SortDirection.descending;
        onChanged(selected, nextDirection);
      },
      itemBuilder: (context) => [
        for (final item in DeviceSortField.values)
          PopupMenuItem(
            value: item,
            child: Row(
              children: [
                Icon(
                  item == field
                      ? (direction == SortDirection.descending
                            ? Icons.arrow_downward
                            : Icons.arrow_upward)
                      : Icons.sort,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '${item.displayName}'
                  '${item == field ? '(${direction.displayName})' : ''}',
                ),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 18),
            const SizedBox(width: 4),
            Text('${field.displayName}·${direction.displayName}'),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}
