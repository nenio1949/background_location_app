import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';
import 'package:background_locator_2/location_dto.dart';
import 'file_manager.dart';
import 'package:flutter/foundation.dart';

class LocationServiceRepository {
  static final LocationServiceRepository _instance =
      LocationServiceRepository._();

  LocationServiceRepository._();

  factory LocationServiceRepository() {
    return _instance;
  }

  static const String isolateName = 'LocatorIsolate';

  int _count = -1;

  /// 初始化
  Future<void> init(Map<dynamic, dynamic> params) async {
    debugPrint("***********Init callback handler");
    if (params.containsKey('countInit')) {
      dynamic tmpCount = params['countInit'];
      if (tmpCount is double) {
        _count = tmpCount.toInt();
      } else if (tmpCount is String) {
        _count = int.parse(tmpCount);
      } else if (tmpCount is int) {
        _count = tmpCount;
      } else {
        _count = -2;
      }
    } else {
      _count = 0;
    }
    debugPrint("$_count");
    await setLogLabel("start");
    final SendPort? send = IsolateNameServer.lookupPortByName(isolateName);
    send?.send(null);
  }

  /// 释放
  Future<void> dispose() async {
    debugPrint("***********Dispose callback handler");
    debugPrint("$_count");
    await setLogLabel("end");
    final SendPort? send = IsolateNameServer.lookupPortByName(isolateName);
    send?.send(null);
  }

  /// 回调
  Future<void> callback(LocationDto locationDto) async {
    debugPrint("$_count ${DateTime.now()} $locationDto");
    // await setLogPosition(_count, locationDto);
    SendPort? send = IsolateNameServer.lookupPortByName(isolateName);
    send?.send(locationDto.toJson());
    _count++;
  }

  /// 打印标签（开始/结束）
  static Future<void> setLogLabel(String label) async {
    final date = DateTime.now();
    await FileManager.writeToLogFile(
        '------------\n$label: ${formatDateLog(date)}\n------------\n');
  }

  /// 打印定位日志
  static Future<void> setLogPosition(int count, LocationDto data) async {
    final date = DateTime.now();
    // await FileManager.writeToLogFile(
    //     '$count : ${formatDateLog(date)} --> ${formatLog(data)} --- isMocked: ${data.isMocked}\n');
    await FileManager.writeToLogFile(
        '$count : ${formatDateLog(date)} --> ${formatLog(data)} \n');
  }

  static double dp(double val, int places) {
    num mod = pow(10.0, places);
    return ((val * mod).round().toDouble() / mod);
  }

  /// 格式化时间
  static String formatDateLog(DateTime date) {
    return "${date.hour}:${date.minute}:${date.second}";
  }

  /// 格式化日志
  static String formatLog(LocationDto locationDto) {
    return "${dp(locationDto.latitude, 15)} ${dp(locationDto.longitude, 15)}";
  }
}
