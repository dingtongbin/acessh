// Copyright (c) 2026 dingtongbin <https://github.com/dingtongbin>.
// SPDX-License-Identifier: AGPL-3.0-only

import 'package:acessh/features/device/application/device_sorter.dart';
import 'package:acessh/features/device/domain/auth_method.dart';
import 'package:acessh/features/device/domain/connection_type.dart';
import 'package:acessh/features/device/domain/device.dart';
import 'package:acessh/features/device/domain/device_sort_field.dart';
import 'package:flutter_test/flutter_test.dart';

Device buildDevice({
  required String name,
  required String host,
  String username = 'root',
  int createdAt = 0,
  int openCount = 0,
  int? lastConnectedAt,
}) {
  return Device(
    name: name,
    type: ConnectionType.ssh,
    host: host,
    port: 22,
    username: username,
    password: '',
    authMethod: AuthMethod.password,
    privateKey: '',
    privateKeyPassphrase: '',
    hostKey: '',
    baudRate: 115200,
    note: '',
    tag: '',
    openCount: openCount,
    lastConnectedAt: lastConnectedAt,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

void main() {
  final devices = [
    buildDevice(
      name: '生产服务器',
      host: '10.0.0.1',
      createdAt: 100,
      openCount: 3,
      lastConnectedAt: 300,
    ),
    buildDevice(
      name: '测试机',
      host: '106.12.90.186',
      username: 'tester',
      createdAt: 200,
      openCount: 10,
      lastConnectedAt: 100,
    ),
    buildDevice(
      name: 'router',
      host: '192.168.1.1',
      createdAt: 300,
      openCount: 1,
      lastConnectedAt: null,
    ),
  ];

  group('DeviceSorter.filterAndSort', () {
    test('按创建时间倒序(默认)', () {
      final result = DeviceSorter.filterAndSort(
        devices: devices,
        keyword: '',
        sortField: DeviceSortField.createdAt,
        direction: SortDirection.descending,
      );
      expect(result.map((d) => d.name).toList(), ['router', '测试机', '生产服务器']);
    });

    test('按创建时间正序', () {
      final result = DeviceSorter.filterAndSort(
        devices: devices,
        keyword: '',
        sortField: DeviceSortField.createdAt,
        direction: SortDirection.ascending,
      );
      expect(result.map((d) => d.name).toList(), ['生产服务器', '测试机', 'router']);
    });

    test('按打开次数倒序', () {
      final result = DeviceSorter.filterAndSort(
        devices: devices,
        keyword: '',
        sortField: DeviceSortField.openCount,
        direction: SortDirection.descending,
      );
      expect(result.map((d) => d.name).toList(), ['测试机', '生产服务器', 'router']);
    });

    test('按最近登录倒序,未登录过的排在最后', () {
      final result = DeviceSorter.filterAndSort(
        devices: devices,
        keyword: '',
        sortField: DeviceSortField.lastConnectedAt,
        direction: SortDirection.descending,
      );
      expect(result.map((d) => d.name).toList(), ['生产服务器', '测试机', 'router']);
    });

    test('按最近登录正序,未登录过的排在最后', () {
      final result = DeviceSorter.filterAndSort(
        devices: devices,
        keyword: '',
        sortField: DeviceSortField.lastConnectedAt,
        direction: SortDirection.ascending,
      );
      expect(result.map((d) => d.name).toList(), ['测试机', '生产服务器', 'router']);
    });

    test('关键字过滤命中会话名,不区分大小写', () {
      final result = DeviceSorter.filterAndSort(
        devices: devices,
        keyword: 'ROUTER',
        sortField: DeviceSortField.createdAt,
        direction: SortDirection.descending,
      );
      expect(result.map((d) => d.name).toList(), ['router']);
    });

    test('关键字过滤命中主机', () {
      final result = DeviceSorter.filterAndSort(
        devices: devices,
        keyword: '106.12',
        sortField: DeviceSortField.createdAt,
        direction: SortDirection.descending,
      );
      expect(result.map((d) => d.name).toList(), ['测试机']);
    });

    test('关键字过滤命中用户名', () {
      final result = DeviceSorter.filterAndSort(
        devices: devices,
        keyword: 'tester',
        sortField: DeviceSortField.createdAt,
        direction: SortDirection.descending,
      );
      expect(result.map((d) => d.name).toList(), ['测试机']);
    });

    test('无命中时返回空列表', () {
      final result = DeviceSorter.filterAndSort(
        devices: devices,
        keyword: '不存在',
        sortField: DeviceSortField.createdAt,
        direction: SortDirection.descending,
      );
      expect(result, isEmpty);
    });

    test('空设备列表返回空列表', () {
      final result = DeviceSorter.filterAndSort(
        devices: const [],
        keyword: '',
        sortField: DeviceSortField.createdAt,
        direction: SortDirection.descending,
      );
      expect(result, isEmpty);
    });

    test('不修改原始列表', () {
      final original = List<Device>.of(devices);
      DeviceSorter.filterAndSort(
        devices: devices,
        keyword: '',
        sortField: DeviceSortField.openCount,
        direction: SortDirection.ascending,
      );
      expect(devices, original);
    });
  });
}
