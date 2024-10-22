import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:battery_status/screens/HomePage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyDwY0KjwQIIX8Y-nB-GpO-EaRH5ABcjcPo',
      appId: '1:941998753950:android:d184cc68bc51e1bfd2138f',
      messagingSenderId: '941998753950',
      projectId: 'battery-status-detection',
    ),
  );


  BatteryService batteryService = BatteryService();
  await batteryService.initialize();


  await batteryService._showNotification(
    message.notification?.title ?? "Notification",
    message.notification?.body ?? "You have a new message.",
  );
}


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyDwY0KjwQIIX8Y-nB-GpO-EaRH5ABcjcPo',
      appId: '1:941998753950:android:d184cc68bc51e1bfd2138f',
      messagingSenderId: '941998753950',
      projectId: 'battery-status-detection',
    ),
  );


  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    BatteryService batteryService = BatteryService();
    batteryService._showNotification(
      message.notification?.title ?? "Notification",
      message.notification?.body ?? "You have a new message.",
    );
    print('Received a foreground message: ${message.notification?.title}');
  });

  String? fcmToken = await FirebaseMessaging.instance.getToken();
  print("FCM Token: $fcmToken");


  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);


  final androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: "Battery Status",
    notificationText: "Monitoring battery levels.",
  );

  bool initialized = await FlutterBackground.initialize(androidConfig: androidConfig);

  if (initialized) {

    await FlutterBackground.enableBackgroundExecution();
  } else {
    print("Failed to initialize FlutterBackground");
  }

  runApp(MyApp());
}




class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Battery Level Detection',
      home: HomePage(),
    );
  }
}


class BatteryService {
  final Battery _battery = Battery();
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  StreamSubscription<BatteryState>? _batteryStateSubscription;
  StreamSubscription<int>? _batteryLevelSubscription;
  StreamSubscription<dynamic>? _appLifecycleSubscription;
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  static int batteryLimit = 80;
  static int notificationFrequency = 10;
  static int snoozeTimes = 3;
  static String selectedTune = 'assets/alarm.mp3';

  final AudioPlayer _audioPlayer = AudioPlayer();
  int _notificationCount = 0;
  bool _isBackgroundMonitoring = false;
  BatteryService();


  BatteryState? _previousBatteryState;
  bool _isCharging = false;
  final _batteryStateController = StreamController<BatteryState>.broadcast();
  final _batteryLevelController = StreamController<int>.broadcast();

  Stream<BatteryState> get onBatteryStateChanged => _batteryStateController.stream;
  Stream<int> get onBatteryLevelChanged => _batteryLevelController.stream;

  Future<void> initialize() async {
    await _initializeNotifications();
    await _loadSettings();
    final initialLevel = await _battery.batteryLevel;
    String deviceId = await _getDeviceId();
    await _loadSelectedTune();
    _batteryLevelController.add(initialLevel);
    _requestPermissions();
    startMonitoring();
    _battery.onBatteryStateChanged.listen((BatteryState state) {
      String batteryStateString = state.toString();
      sendBatteryStatusToServer(deviceId, initialLevel, batteryStateString);
    });

  }
  Future<String> _getDeviceId() async {
    if (Platform.isAndroid) {
      var androidInfo = await _deviceInfoPlugin.androidInfo;
      return androidInfo.id;
    }
    return "unknown_device_id";
  }


  Future<void> sendBatteryStatusToServer(String deviceId, int batteryLevel, String batteryState) async {
    final response = await http.post(
      Uri.parse('http://192.168.73.27/battery/send-fcm.php'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, dynamic>{
        'deviceId': deviceId,
        'batteryLevel': batteryLevel,
        'batteryState': batteryState,
      }),
    );

    if (response.statusCode == 200) {
      print('Battery status sent successfully.');
    } else {
      print('Failed to send battery status. Response: ${response.body}');
    }
  }


  Future<void> startBackgroundMonitoring() async {
    if (_isBackgroundMonitoring) return;
    _isBackgroundMonitoring = true;

    final hasPermissions = await FlutterBackground.hasPermissions;
    if (!hasPermissions) {
      final permissionGranted = await FlutterBackground.initialize();
      if (!permissionGranted) {
        return;
      }
    }


    _batteryStateSubscription = _battery.onBatteryStateChanged.listen((BatteryState state) async {
      await _handleBatteryStateChange(state);
    });


    _batteryLevelSubscription = Stream.periodic(Duration(seconds: notificationFrequency))
        .asyncMap((_) => _battery.batteryLevel)
        .listen((level) async {
      await _handleBatteryLevelChange(level);
    });

    SystemChannels.lifecycle.setMessageHandler((msg) async {
      if (msg == AppLifecycleState.paused.toString()) {

        await FlutterBackground.enableBackgroundExecution();
      } else if (msg == AppLifecycleState.resumed.toString()) {

        await FlutterBackground.disableBackgroundExecution();
      }
      return;
    });

  }

  Future<void> stopBackgroundMonitoring() async {
    if (!_isBackgroundMonitoring) return;
    _isBackgroundMonitoring = false;


    await _batteryStateSubscription?.cancel();
    await _batteryLevelSubscription?.cancel();


    await FlutterBackground.disableBackgroundExecution();
  }

  Future<void> _handleBatteryStateChange(BatteryState state) async {
    switch (state) {
      case BatteryState.charging:
        await _showNotification("Charging", "Your device is now charging.");
        break;
      case BatteryState.full:
        await _showNotification("Battery Full", "Your battery is fully charged.");
        break;
      case BatteryState.discharging:
        await _showNotification("Discharging", "Your device is unplugged and discharging.");
        break;
      case BatteryState.unknown:
      case BatteryState.connectedNotCharging:
        await _showNotification("Battery State Change", "Battery state changed to ${state.toString()}");
        break;
    }
  }

  Future<void> _handleBatteryLevelChange(int level) async {
    if (level >= batteryLimit && _isCharging) {
      await _showNotification("Battery Limit Reached", "Battery level has reached $level%. Please unplug your charger.");
      await _playAlarm();
    }
  }


  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    batteryLimit = prefs.getInt('batteryLimit') ?? 80;
    notificationFrequency = prefs.getInt('notificationFrequency') ?? 10;
    snoozeTimes = prefs.getInt('snoozeTimes') ?? 3;
    selectedTune = prefs.getString('selectedTune') ?? 'assets/alarm.mp3';
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
      if (await Permission.ignoreBatteryOptimizations.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }
  }

  // Load selected tune from SharedPreferences
  Future<void> _loadSelectedTune() async {
    final prefs = await SharedPreferences.getInstance();
    selectedTune = prefs.getString('selectedTune') ?? 'assets/alarm.mp3'; // Default to 'assets/alarm.mp3' if none saved
  }

  // Save the selected tune to SharedPreferences
  Future<void> _saveSelectedTune(String tunePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedTune', tunePath);
  }

  void updateSettings(int newLimit, int newFrequency, int newSnooze, String newTune) {
    batteryLimit = newLimit;
    notificationFrequency = newFrequency;
    snoozeTimes = newSnooze;
    selectedTune = newTune;
    startMonitoring(); // Restart monitoring with new settings
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Notification Tapped: ${response.payload}');
      },
    );
  }


  Future<void> startMonitoring() async {
    _batteryStateSubscription = _battery.onBatteryStateChanged.listen((BatteryState state) async {
      _batteryStateController.add(state);
      if (_previousBatteryState == null) {
        _previousBatteryState = state;
        return;
      }

      if (state != _previousBatteryState) {
        switch (state) {
          case BatteryState.charging:
            _isCharging = true;
            _notificationCount = 0;
            await _showNotification("Charging", "Your device is now charging.");
            break;
          case BatteryState.full:
            _isCharging = true;
            await _showNotification("Battery Full", "Your battery is fully charged.");
            break;
          case BatteryState.discharging:
            _isCharging = false;
            await _showNotification("Charger Disconnected", "Your device is unplugged and discharging.");
            break;
          case BatteryState.unknown:
          case BatteryState.connectedNotCharging:

            if (_previousBatteryState == BatteryState.charging || _previousBatteryState == BatteryState.discharging) {
              await _showNotification(
                "Charger ${state == BatteryState.connectedNotCharging ? 'Disconnected' : 'Connected'}",
                "Your device is now ${state == BatteryState.connectedNotCharging ? 'disconnected' : 'connected'}.",
              );
            }
            _isCharging = state == BatteryState.charging;
            break;
        }
        _previousBatteryState = state;
      }
    });

    _batteryLevelSubscription = Stream.periodic(Duration(seconds: notificationFrequency))
        .asyncMap((_) async {
      final prefs = await SharedPreferences.getInstance();
      batteryLimit = prefs.getInt('batteryLimit') ?? batteryLimit;

      return _battery.batteryLevel;
    }).listen((level) {
      _batteryLevelController.add(level);


      if (_previousBatteryState == BatteryState.charging && level >= batteryLimit && _notificationCount <= snoozeTimes) {
        _playAlarm();
         _showNotification("Battery Limit Reached to $batteryLimit", "Please Unplug your charger.");
        _notificationCount++;
      }
    });

    WidgetsBinding.instance.addObserver(LifecycleEventHandler(
      detachedCallBack: () async {

        await _showNotification("App Terminated", "The app has been closed.");
      },
      resumeCallBack: () async {

        await _showNotification("App Resumed", "Welcome back to the app.");
      },
      pauseCallBack: () async {

        await _showNotification("App Paused", "The app is now in the background.");
      }, batteryService: BatteryService(),
    ));
  }

  Future<void> _playAlarm() async {
    try {
      if (selectedTune.startsWith('assets/')) {
        await _audioPlayer.play(AssetSource(selectedTune));
      } else {
        await _audioPlayer.play(DeviceFileSource(selectedTune));
      }

      // Future.delayed(Duration(seconds: 15), () {
      //   _audioPlayer.stop();
      // });
    } catch (e) {
      print('Error playing selected tune: $e');
    }
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'battery_channel',
      'Battery Notifications',
      channelDescription: 'Notifications for battery status',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: 'battery_payload',
    );
  }

  Future<void> scheduleNotification(int id, String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'battery_channel',
      'Battery Notifications',
      channelDescription: 'Notifications for battery status',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)), // Change this for your scheduling
      platformChannelSpecifics,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }


  void dispose() {
    _batteryStateSubscription?.cancel();
    _batteryLevelSubscription?.cancel();
    _audioPlayer.dispose();
  }
}


class LifecycleEventHandler extends WidgetsBindingObserver {
  final AsyncCallback? detachedCallBack;
  final AsyncCallback? resumeCallBack;
  final AsyncCallback? pauseCallBack;
  final BatteryService batteryService;

  LifecycleEventHandler({this.detachedCallBack, this.resumeCallBack, this.pauseCallBack, required this.batteryService});

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.detached:
        detachedCallBack?.call();
        break;
      case AppLifecycleState.resumed:
        resumeCallBack?.call();
        await batteryService.stopBackgroundMonitoring(); // Stop monitoring when the app is resumed
        break;
      case AppLifecycleState.paused:
        pauseCallBack?.call();
        await batteryService.startBackgroundMonitoring(); // Start monitoring when the app is paused (background)
        break;
      case AppLifecycleState.inactive:

        break;
      default:
        break;
    }
  }
}
