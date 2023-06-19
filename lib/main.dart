import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:background_locator_2/settings/android_settings.dart';
import 'package:background_locator_2/settings/ios_settings.dart';
import 'package:background_locator_2/settings/locator_settings.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:background_locator_2/background_locator.dart';
import 'package:background_locator_2/location_dto.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'file_manager.dart';
import 'location_callback_handler.dart';
import 'location_service_repository.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

@pragma('vm:entry-point')
class MyAppState extends State<MyApp> {
  ReceivePort port = ReceivePort();

  String logStr = '';
  late bool isRunning = false;
  late LocationDto? lastLocation;
  late WebViewController controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(const Color(0x00000000))
    ..setNavigationDelegate(NavigationDelegate(
        onProgress: (int progress) {},
        onPageStarted: (String url) {},
        onPageFinished: (String url) {},
        onWebResourceError: (WebResourceError error) {},
        onNavigationRequest: (NavigationRequest request) {
          if (request.url.startsWith('https://www.youtube.com/')) {
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        }))
    ..addJavaScriptChannel('flutterMessage',
        onMessageReceived: (JavaScriptMessage message) {
      debugPrint("收到web端消息：${message.message}");
      var action = message.message;
      switch (action) {
        case 'start':
          _onStart();
          break;
        case 'stop':
          onStop();
          break;
        case 'clear':
          FileManager.clearLogFile();
          break;
      }
    })
    ..loadFlutterAsset('assets/index.html');

  @override
  void initState() {
    super.initState();

    if (IsolateNameServer.lookupPortByName(
            LocationServiceRepository.isolateName) !=
        null) {
      IsolateNameServer.removePortNameMapping(
          LocationServiceRepository.isolateName);
    }

    IsolateNameServer.registerPortWithName(
        port.sendPort, LocationServiceRepository.isolateName);

    /// 端口监听定位回调
    port.listen(
      (data) async {
        if (data != null) {
          Map<dynamic, dynamic> result = <dynamic, dynamic>{};
          for (dynamic type in data.keys) {
            result[type] = data[type];
          }
          var location = LocationDto.fromJson(result);
          var msg =
              "${DateTime.now()} 经度：${location.longitude},纬度：${location.latitude}";
          controller.runJavaScript('flutterMessage.webReceiveMessage("$msg")');
          // await updateUI(LocationDto.fromJson(result));
        }
      },
    );
    initPlatformState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> updateUI(LocationDto data) async {
    final log = await FileManager.readLogFile();

    await _updateNotificationText(data);

    setState(() {
      lastLocation = data;
      logStr = log;
    });
  }

  Future<void> _updateNotificationText(LocationDto data) async {
    await BackgroundLocator.updateNotificationText(
        title: "已收到新的位置",
        msg: "${DateTime.now()}",
        bigMsg: "${data.latitude}, ${data.longitude}");
  }

  Future<void> initPlatformState() async {
    debugPrint('Initializing...');
    await BackgroundLocator.initialize();
    logStr = await FileManager.readLogFile();
    debugPrint('Initialization done');
    final running = await BackgroundLocator.isServiceRunning();
    setState(() {
      isRunning = running;
    });
    debugPrint('Running ${isRunning.toString()}');
  }

  @override
  Widget build(BuildContext context) {
    // final start = SizedBox(
    //   width: double.maxFinite,
    //   child: ElevatedButton(
    //     child: const Text('开始位置跟踪'),
    //     onPressed: () {
    //       _onStart();
    //     },
    //   ),
    // );
    // final stop = SizedBox(
    //   width: double.maxFinite,
    //   child: ElevatedButton(
    //     child: const Text('停止位置跟踪'),
    //     onPressed: () {
    //       onStop();
    //     },
    //   ),
    // );
    // final clear = SizedBox(
    //   width: double.maxFinite,
    //   child: ElevatedButton(
    //     child: const Text('清除记录'),
    //     onPressed: () {
    //       FileManager.clearLogFile();
    //       setState(() {
    //         logStr = '';
    //       });
    //     },
    //   ),
    // );
    // String msgStatus = "-";
    // if (isRunning) {
    //   msgStatus = '正在运行';
    // } else {
    //   msgStatus = '未运行';
    // }
    // final status = Text("状态: $msgStatus");

    // final log = Text(
    //   logStr,
    // );

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('后台定位'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await controller.canGoBack()) {
                controller.goBack();
              } else {
                if (context.mounted && Navigator.canPop(context)) {
                  Navigator.of(context).pop();
                }
              }
            },
          ),
        ),
        // body: Container(
        //   width: double.maxFinite,
        //   padding: const EdgeInsets.all(22),
        //   child: SingleChildScrollView(
        //     child: Column(
        //       crossAxisAlignment: CrossAxisAlignment.center,
        //       children: <Widget>[start, stop, clear, status, log],
        //     ),
        //   ),
        // ),
        body: WillPopScope(
          child: WebViewWidget(controller: controller),
          onWillPop: () async {
            if (await controller.canGoBack()) {
              controller.goBack();
              return false;
            } else {
              return true;
            }
          },
        ),
      ),
    );
  }

  void onStop() async {
    await BackgroundLocator.unRegisterLocationUpdate();
    final running = await BackgroundLocator.isServiceRunning();
    setState(() {
      isRunning = running;
    });
  }

  void _onStart() async {
    if (await _checkLocationPermission()) {
      await _startLocator();
      final running = await BackgroundLocator.isServiceRunning();

      setState(() {
        isRunning = running;
        lastLocation = null;
      });
    } else {
      // show error
    }
  }

  /// 检查位置权限
  Future<bool> _checkLocationPermission() async {
    var storage = await Permission.storage.request();
    if (storage.isGranted) {
      final access = await Permission.locationWhenInUse.status;
      final backAccess = await Permission.locationAlways.status;
      if (access.isGranted && backAccess.isGranted) {
        return true;
      } else {
        return await _getPermission();
      }
    } else {
      return false;
    }
  }

  /// 获取位置权限
  Future<bool> _getPermission() async {
    var status = await Permission.locationWhenInUse.request();
    debugPrint("1111,$status");
    if (status.isGranted) {
      var backStatus = await Permission.locationAlways.request();
      return status.isGranted && backStatus.isGranted;
    } else {
      return false;
    }
  }

  /// 后台定位配置
  Future<void> _startLocator() async {
    Map<String, dynamic> data = {'countInit': 1};
    return await BackgroundLocator.registerLocationUpdate(
        LocationCallbackHandler.callback,
        initCallback: LocationCallbackHandler.initCallback,
        initDataCallback: data,
        disposeCallback: LocationCallbackHandler.disposeCallback,
        iosSettings: const IOSSettings(
          accuracy: LocationAccuracy.NAVIGATION,
          distanceFilter: 0,
          showsBackgroundLocationIndicator: true,
        ),
        autoStop: false,
        androidSettings: const AndroidSettings(
            accuracy: LocationAccuracy.NAVIGATION,
            interval: 30,
            distanceFilter: 0,
            wakeLockTime: 10,
            client: LocationClient.android,
            androidNotificationSettings: AndroidNotificationSettings(
                notificationChannelName: '位置跟踪',
                notificationTitle: '开始位置跟踪',
                notificationMsg: '后台运行位置跟踪',
                notificationBigMsg: '请务必打开位置权限为始终允许，以保证定位功能正常运行',
                notificationIconColor: Colors.grey,
                notificationTapCallback:
                    LocationCallbackHandler.notificationCallback)));
  }
}
