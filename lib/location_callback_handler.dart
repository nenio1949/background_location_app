import 'dart:async';
import 'package:background_locator_2/location_dto.dart';
import 'package:flutter/foundation.dart';
import 'location_service_repository.dart';

@pragma('vm:entry-point')
class LocationCallbackHandler {
  /// 初始化
  @pragma('vm:entry-point')
  static Future<void> initCallback(Map<dynamic, dynamic> params) async {
    LocationServiceRepository myLocationCallbackRepository =
        LocationServiceRepository();
    await myLocationCallbackRepository.init(params);
  }

  /// 释放
  static Future<void> disposeCallback() async {
    LocationServiceRepository myLocationCallbackRepository =
        LocationServiceRepository();
    await myLocationCallbackRepository.dispose();
  }

  /// 回调
  @pragma('vm:entry-point')
  static Future<void> callback(LocationDto locationDto) async {
    LocationServiceRepository myLocationCallbackRepository =
        LocationServiceRepository();
    await myLocationCallbackRepository.callback(locationDto);
  }

  /// 通知回调
  @pragma('vm:entry-point')
  static Future<void> notificationCallback() async {
    debugPrint('***notificationCallback');
  }
}
