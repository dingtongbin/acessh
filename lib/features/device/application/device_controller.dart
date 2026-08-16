// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/foundation.dart';

import '../data/device_repository.dart';
import '../domain/device.dart';
import '../domain/device_sort_field.dart';
import 'device_sorter.dart';

/// 设备列表状态:持有设备数据与文件夹,提供 CRUD、搜索过滤与排序。
class DeviceController extends ChangeNotifier {
  /// 创建设备控制器;不传仓库时使用全局会话文件仓库。
  DeviceController([DeviceRepository? repository])
    : _repository = repository ?? DeviceRepository();

  /// 全局唯一实例。
  static final DeviceController instance = DeviceController();

  final DeviceRepository _repository;

  List<Device> _devices = [];
  List<String> _folders = [];
  final Set<String> _collapsedFolders = {};
  String _keyword = '';
  final Set<String> _selectedTags = {};
  DeviceSortField _sortField = DeviceSortField.createdAt;
  SortDirection _sortDirection = SortDirection.descending;

  /// 过滤排序结果缓存,避免 build 期间重复计算。
  List<Device>? _cachedFilteredDevices;

  /// 标签列表缓存。
  List<String>? _cachedAvailableTags;

  /// 全部设备(未过滤)。
  List<Device> get devices => List.unmodifiable(_devices);

  /// 全部文件夹名(含空文件夹,排除 keys 保留目录)。
  List<String> get folders => List.unmodifiable(_folders);

  /// 已折叠(收起)的文件夹名集合。
  Set<String> get collapsedFolders => Set.unmodifiable(_collapsedFolders);

  /// 当前搜索关键字。
  String get keyword => _keyword;

  /// 已选中的筛选标签(多选聚合)。
  Set<String> get selectedTags => Set.unmodifiable(_selectedTags);

  /// 全部已使用的标签(去重排序)。
  List<String> get availableTags {
    return _cachedAvailableTags ??=
        _devices
            .map((device) => device.tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
  }

  /// 当前排序字段。
  DeviceSortField get sortField => _sortField;

  /// 当前排序方向。
  SortDirection get sortDirection => _sortDirection;

  /// 加载全部设备与文件夹。
  Future<void> load() async {
    _devices = await _repository.queryAll();
    _folders = await _repository.listFolders();
    _invalidateCaches();
    notifyListeners();
  }

  /// 从磁盘刷新设备与文件夹列表。
  Future<void> reload() => load();

  /// 按关键字与标签规则过滤后的设备列表。
  List<Device> get filteredDevices {
    return _cachedFilteredDevices ??= DeviceSorter.filterAndSort(
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
    _invalidateCaches();
    notifyListeners();
  }

  /// 清除全部标签筛选。
  void clearTags() {
    if (_selectedTags.isEmpty) {
      return;
    }
    _selectedTags.clear();
    _invalidateCaches();
    notifyListeners();
  }

  /// 设置搜索关键字。
  void setKeyword(String keyword) {
    _keyword = keyword.trim();
    _invalidateCaches();
    notifyListeners();
  }

  /// 设置排序字段与方向。
  void setSort(DeviceSortField field, SortDirection direction) {
    _sortField = field;
    _sortDirection = direction;
    _invalidateCaches();
    notifyListeners();
  }

  /// 切换文件夹展开/折叠状态。
  void toggleFolder(String name) {
    if (!_collapsedFolders.remove(name)) {
      _collapsedFolders.add(name);
    }
    notifyListeners();
  }

  /// 使过滤/标签缓存失效(设备数据或筛选条件变化时调用)。
  void _invalidateCaches() {
    _cachedFilteredDevices = null;
    _cachedAvailableTags = null;
  }

  /// 按会话名与文件夹查询单个设备,不存在返回 null。
  Future<Device?> queryByName(String name, {String folder = ''}) {
    return _repository.queryByName(name, folder: folder);
  }

  /// 新增设备,失败(如同文件夹会话名重复)时抛出异常。
  Future<void> addDevice(Device device) async {
    await _repository.insert(device);
    await load();
  }

  /// 更新设备;[previousName]/[previousFolder] 为编辑前的会话名与文件夹,
  /// 任一变化时仓库会迁移会话文件。
  Future<void> updateDevice(
    Device device, {
    String? previousName,
    String? previousFolder,
  }) async {
    if ((previousName != null && previousName != device.name) ||
        (previousFolder != null && previousFolder != device.folder)) {
      await _repository.rename(
        previousName ?? device.name,
        previousFolder ?? device.folder,
        device,
      );
    } else {
      await _repository.update(device);
    }
    await load();
  }

  /// 删除设备。
  Future<void> deleteDevice(String name, {String folder = ''}) async {
    await _repository.delete(name, folder: folder);
    await load();
  }

  /// 创建文件夹,名称非法或已存在时抛出异常。
  Future<void> addFolder(String name) async {
    await _repository.createFolder(name);
    await load();
  }

  /// 重命名文件夹。
  Future<void> renameFolder(String oldName, String newName) async {
    await _repository.renameFolder(oldName, newName);
    await load();
  }

  /// 删除文件夹及其中的全部设备。
  Future<void> deleteFolder(String name) async {
    await _repository.deleteFolder(name);
    await load();
  }

  /// 清除设备 SSH 主机指纹。
  Future<void> clearHostKey(String name, {String folder = ''}) async {
    await _repository.clearHostKey(name, folder: folder);
    await load();
  }

  /// 记录设备被成功打开一次(次数 +1,更新最近登录时间)。
  Future<void> recordOpened(String name, {String folder = ''}) async {
    await _repository.recordOpened(name, folder: folder);
    await load();
  }
}
