import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

class BatteryWorkManager {
  static const String batteryWorkName = 'batteryMonitoringWork';

  static Future<void> registerPeriodicWork() async {
    final workManager = Workmanager();
    await workManager.initialize(callbackDispatcher);

    await workManager.registerPeriodicTask(
      batteryWorkName,
      batteryWorkName,
      frequency: Duration(seconds: 1), // Minimum allowed frequency
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
        requiresCharging: false,
      ),
    );
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    final battery = Battery();
    final level = await battery.batteryLevel;
    final state = await battery.batteryState;

    // Recreate your notification logic here
    await checkAndNotify(level, state);
    return Future.value(true);
  });
}

Future<void> checkAndNotify(int level, BatteryState state) async {
  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();
  final SharedPreferences prefs = await SharedPreferences.getInstance();

// Get stored settings
  final int batteryLimit = prefs.getInt('batteryLimit') ?? 80;
  final int snoozeTimes = prefs.getInt('snoozeTimes') ?? 3;
  final String previousStateStr = prefs.getString('previousBatteryState') ?? '';
  final BatteryState previousState = _stringToBatteryState(previousStateStr);
  final int notificationCount = prefs.getInt('notificationCount') ?? 0;

// Check if notification is needed
  bool shouldNotify = false;
  String? notificationTitle;
  String? notificationBody;

// Handle state changes
  if (previousState != state) {
    switch (state) {
      case BatteryState.charging:
        shouldNotify = true;
        notificationTitle = "Charging";
        notificationBody = "Your device is now charging.";
        await prefs.setInt(
            'notificationCount', 0); // Reset count when charging starts
        break;
      case BatteryState.full:
        shouldNotify = true;
        notificationTitle = "Battery Full";
        notificationBody = "Your battery is fully charged.";
        break;
      case BatteryState.discharging:
        shouldNotify = true;
        notificationTitle = "Charger Disconnected";
        notificationBody = "Your device is unplugged and discharging.";
        break;
      case BatteryState.unknown:
      case BatteryState.connectedNotCharging:
      shouldNotify = true;
      notificationTitle = "Charger Disconnected";
      notificationBody = "Your device is unplugged and discharging.";
      break;
// Handle if needed
        break;
    }

// Update stored state
    await prefs.setString('previousBatteryState', state.toString());
  }

// Check battery limit
  if (state == BatteryState.charging &&
      level >= batteryLimit &&
      notificationCount < snoozeTimes) {
    shouldNotify = true;
    notificationTitle = "Battery Limit Reached";
    notificationBody = "Please unplug your charger.";
    await prefs.setInt('notificationCount', notificationCount);
  }

// Show notification if needed
  if (shouldNotify && notificationTitle != null && notificationBody != null) {
    await _showBackgroundNotification(
        notifications, notificationTitle, notificationBody);
  }
}

// Helper method to convert string to BatteryState
BatteryState _stringToBatteryState(String stateStr) {
  switch (stateStr) {
    case 'BatteryState.charging':
      return BatteryState.charging;
    case 'BatteryState.discharging':
      return BatteryState.discharging;
    case 'BatteryState.full':
      return BatteryState.full;
    case 'BatteryState.connectedNotCharging':
      return BatteryState.connectedNotCharging;
    default:
      return BatteryState.unknown;
  }
}

// Helper method to show notification
Future<void> _showBackgroundNotification(
  FlutterLocalNotificationsPlugin notifications,
  String title,
  String body,
) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'battery_channel',
    'Battery Notifications',
    channelDescription: 'Notifications for battery status',
    importance: Importance.max,
    priority: Priority.high,
  );

  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );

  await notifications.show(
    0,
    title,
    body,
    platformChannelSpecifics,
  );
}
