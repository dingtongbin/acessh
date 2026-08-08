// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/foundation.dart';

import '../data/device_repository.dart';
import '../domain/device.dart';
import '../domain/device_sort_field.dart';
import 'device_sorter.dart';

/// 设备列表状态:持有设备数据,提供 CRUD、搜索过滤与排序。
class DeviceController extends ChangeNotifier {
  /// 创建设备控制器;不传仓库时使用全局应用数据库。
  DeviceController([DeviceRepository? repository])
    : _repository = repository ?? DeviceRepository();

  /// 全局唯一实例。
  static final DeviceController instance = DeviceController();

  final DeviceRepository _repository;

  List<Device> _devices = [];
  String _keyword = '';
  final Set<String> _selectedTags = {};
  DeviceSortField _sortField = DeviceSortField.createdAt;
  SortDirection _sortDirection = SortDirection.descending;

  /// 全部设备(未过滤)。
  List<Device> get devices => List.unmodifiable(_devices);

  /// 当前搜索关键字。
  String get keyword => _keyword;

  /// 已选中的筛选标签(多选聚合)。
  Set<String> get selectedTags => Set.unmodifiable(_selectedTags);

  /// 全部已使用的标签(去重排序)。
  List<String> get availableTags {
    final tags =
        _devices
            .map((device) => device.tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return tags;
  }

  /// 当前排序字段。
  DeviceSortField get sortField => _sortField;

  /// 当前排序方向。
  SortDirection get sortDirection => _sortDirection;

  /// 加载全部设备。
  Future<void> load() async {
    _devices = await _repository.queryAll();
    notifyListeners();
  }

  /// 从数据库刷新设备列表。
  Future<void> reload() => load();

  /// 按关键字与标签规则过滤后的设备列表。
  List<Device> get filteredDevices {
    return DeviceSorter.filterAndSort(
      devices: _devices.where(_matchesTag).toList(),
      keyword: _keyword,
      sortField: _sortField,
      direction: _sortDirection,
    );
  }

  /// 设备是否命中已选标签(多选聚合:命中任一即通过)。
  bool _matchesTag(Device device) {
    if (_selectedTags.isEmpty) {
      return true;
    }
    final tag = device.tag.trim();
    return tag.isNotEmpty && _selectedTags.contains(tag);
  }

  /// 切换标签筛选(多选聚合)。
  void toggleTag(String tag) {
    if (_selectedTags.contains(tag)) {
      _selectedTags.remove(tag);
    } else {
      _selectedTags.add(tag);
    }
    notifyListeners();
  }

  /// 清除全部标签筛选。
  void clearTags() {
    if (_selectedTags.isEmpty) {
      return;
    }
    _selectedTags.clear();
    notifyListeners();
  }

  /// 设置搜索关键字。
  void setKeyword(String keyword) {
    _keyword = keyword.trim();
    notifyListeners();
  }

  /// 设置排序字段与方向。
  void setSort(DeviceSortField field, SortDirection direction) {
    _sortField = field;
    _sortDirection = direction;
    notifyListeners();
  }

  /// 按会话名查询单个设备,不存在返回 null。
  Future<Device?> queryByName(String name) {
    return _repository.queryByName(name);
  }

  /// 新增设备,失败(如会话名重复)时抛出异常。
  Future<void> addDevice(Device device) async {
    await _repository.insert(device);
    await load();
  }

  /// 更新设备。
  Future<void> updateDevice(Device device) async {
    await _repository.update(device);
    await load();
  }

  /// 删除设备。
  Future<void> deleteDevice(String name) async {
    await _repository.delete(name);
    await load();
  }

  /// 清除设备 SSH 主机指纹。
  Future<void> clearHostKey(String name) async {
    await _repository.clearHostKey(name);
    await load();
  }

  /// 记录设备被成功打开一次(次数 +1,更新最近登录时间)。
  Future<void> recordOpened(String name) async {
    await _repository.recordOpened(name);
    await load();
  }
}
