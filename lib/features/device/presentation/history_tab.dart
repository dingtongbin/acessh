// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import '../../../core/utils/date_formatter.dart';
import '../../connection/data/connection_record_repository.dart';
import '../../connection/domain/connection_record.dart';
import '../domain/connection_type.dart';

/// 连接记录 Tab:展示历史连接的成败与时间,支持下拉刷新。
class HistoryTab extends StatefulWidget {
  /// 创建连接记录 Tab;不传仓库时使用全局应用数据库。
  const HistoryTab({this.repository, super.key});

  /// 连接记录仓库,便于测试注入。
  final ConnectionRecordRepository? repository;

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  late final ConnectionRecordRepository _repository =
      widget.repository ?? ConnectionRecordRepository();
  late Future<List<ConnectionRecord>> _recordsFuture = _load();

  /// 加载最近连接记录。
  Future<List<ConnectionRecord>> _load() {
    return _repository.queryRecent();
  }

  /// 下拉刷新记录。
  Future<void> _refresh() {
    setState(() => _recordsFuture = _load());
    return _recordsFuture.then((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ConnectionRecord>>(
      future: _recordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final records = snapshot.data ?? const [];
        if (records.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: [
                const SizedBox(height: 120),
                Icon(
                  Icons.history,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '暂无连接记录,下拉刷新',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: records.length,
            separatorBuilder: (_, _) =>
                const Divider(indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final record = records[index];
              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: Icon(
                  record.isSuccess ? Icons.check_circle : Icons.cancel,
                  size: 20,
                  color: record.isSuccess ? Colors.green : Colors.red,
                ),
                title: Text(
                  record.deviceName,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: Text(
                  '${ConnectionType.fromStorage(record.deviceType).displayName}'
                  ' · ${DateFormatter.formatMillis(record.connectedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: Text(
                  record.isSuccess ? '成功' : '失败',
                  style: TextStyle(
                    color: record.isSuccess ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
