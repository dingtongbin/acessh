// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import '../../device/presentation/connected_tab.dart';
import '../../device/presentation/device_list_tab.dart';
import '../../device/presentation/history_tab.dart';
import '../../device/presentation/quick_add_sheet.dart';
import 'search_dialog.dart';

/// 主页:顶部常规 AppBar(左上角快速添加、右侧搜索)+ 内容区顶部 Tab。
class HomeScreen extends StatefulWidget {
  /// 创建主页。
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('主页'),
          leading: IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 28),
            tooltip: '快速添加设备',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (context) => const QuickAddSheet(),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: '搜索设备',
              onPressed: () => _showSearchDialog(context),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '设备列表'),
              Tab(text: '已连接'),
              Tab(text: '连接记录'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [DeviceListTab(), ConnectedTab(), HistoryTab()],
        ),
      ),
    );
  }

  /// 弹出模糊搜索对话框。
  void _showSearchDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const SearchDialog(),
    );
  }
}
