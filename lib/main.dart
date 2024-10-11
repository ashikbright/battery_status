import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:battery_status/HomePage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyDwY0KjwQIIX8Y-nB-GpO-EaRH5ABcjcPo',
      appId: '1:941998753950:android:d184cc68bc51e1bfd2138f',
      messagingSenderId: '941998753950',
      projectId: 'battery-status-detection',
    ),
  );

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

  static int batteryLimit = 80;
  static int notificationFrequency = 10;
  static int snoozeTimes = 3; // How many times to repeat notifications
  static String selectedTune = 'assets/alarm.mp3';

  final AudioPlayer _audioPlayer = AudioPlayer();
  int _notificationCount = 0;

  BatteryService();

  // Track the previous battery state and charging state
  BatteryState? _previousBatteryState;
  bool _isCharging = false;
  final _batteryStateController = StreamController<BatteryState>.broadcast();
  final _batteryLevelController = StreamController<int>.broadcast();

  Stream<BatteryState> get onBatteryStateChanged => _batteryStateController.stream;
  Stream<int> get onBatteryLevelChanged => _batteryLevelController.stream;

  Future<void> initialize() async {
    await _initializeNotifications();
    final initialLevel = await _battery.batteryLevel;
    await _loadSelectedTune();
    _batteryLevelController.add(initialLevel);
    _requestPermissions();
    startMonitoring();
  }

   Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
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
    selectedTune =   _saveSelectedTune(newTune) as String; ;
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


  void startMonitoring() {
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
            _notificationCount = 0; // Reset notification count when charging starts
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
          // No notification for connectedNotCharging or unknown states
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

      // Ensure alerts only happen when the device is discharging and the level is above the limit
      if (_previousBatteryState == BatteryState.charging && level >= batteryLimit && _notificationCount <= snoozeTimes) {
        _playAlarm();
        _notificationCount++;
      }
    });
  }

  Future<void> _playAlarm() async {
    try {
      if (selectedTune.startsWith('assets/')) {
        await _audioPlayer.play(AssetSource(selectedTune));
      } else {
        await _audioPlayer.play(DeviceFileSource(selectedTune));
      }

      Future.delayed(Duration(seconds: 15), () {
        _audioPlayer.stop();
      });
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

  void dispose() {
    _batteryStateSubscription?.cancel();
    _batteryLevelSubscription?.cancel();
    _audioPlayer.dispose();
  }
}