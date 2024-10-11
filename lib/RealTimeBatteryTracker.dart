import 'dart:async';
import 'dart:convert';

import 'package:battery_plus/battery_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RealTimeBatteryTracker extends StatefulWidget {
  @override
  _RealTimeBatteryTrackerState createState() => _RealTimeBatteryTrackerState();
}

class _RealTimeBatteryTrackerState extends State<RealTimeBatteryTracker> {
  Battery _battery = Battery();
  List<Map<String, dynamic>> _batteryHistory = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadBatteryHistory();

    // Fetch battery level every 5 minutes (adjust the duration as needed)
    _timer = Timer.periodic(Duration(minutes: 5), (timer) {
      _getBatteryLevel();
    });

    // Fetch battery level initially to test if data is being fetched
    _getBatteryLevel();
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  Future<void> _getBatteryLevel() async {
    final batteryLevel = await _battery.batteryLevel;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    print('Battery level fetched: $batteryLevel%'); // Debugging: Check battery level

    // Save the battery level along with the timestamp
    _batteryHistory.add({'timestamp': timestamp, 'level': batteryLevel});

    // Remove entries older than 24 hours
    final twentyFourHoursAgo = DateTime.now().subtract(Duration(hours: 24)).millisecondsSinceEpoch;
    _batteryHistory.removeWhere((entry) => entry['timestamp'] < twentyFourHoursAgo);

    print('Battery history: $_batteryHistory'); // Debugging: Check battery history

    // Save the updated battery data
    await _saveBatteryHistory();

    // Update the UI
    setState(() {});
  }

  Future<void> _saveBatteryHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('battery_history', jsonEncode(_batteryHistory));

    print('Battery history saved to SharedPreferences'); // Debugging: Check if saved
  }

  Future<void> _loadBatteryHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final batteryHistoryString = prefs.getString('battery_history');

    if (batteryHistoryString != null) {
      setState(() {
        _batteryHistory = List<Map<String, dynamic>>.from(jsonDecode(batteryHistoryString));
        print('Battery history loaded: $_batteryHistory'); // Debugging: Check if loaded correctly
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Battery Level - Last 24 Hours'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: _batteryHistory.isEmpty
                  ? Center(child: Text('No data available'))
                  : LineChart(_buildLineChartData()),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildLineChartData() {
    List<FlSpot> spots = [];

    for (var entry in _batteryHistory) {
      // Calculate hours ago
      double hoursAgo = (DateTime.now().millisecondsSinceEpoch - entry['timestamp']) / (1000 * 3600);
      double level = entry['level'].toDouble();
      spots.add(FlSpot(24 - hoursAgo, level)); // Display in reverse chronological order
    }

    return LineChartData(
      gridData: FlGridData(show: true),
      borderData: FlBorderData(show: true),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40, // Space reserved for titles
            interval: 3, // Show labels every 3 hours
            getTitlesWidget: (value, _) {
              // Only show titles for 0, 3, 6, 9, 12, 15, 18, 21 hours ago
              if (value % 3 == 0) {
                int hoursAgo = (24 - value).toInt(); // Convert to hours ago
                return Text('${hoursAgo}h'); // Display "h ago"
              }
              return SizedBox.shrink(); // Return an empty widget for other values
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: 25, // Battery level in intervals of 25
            getTitlesWidget: (value, _) {
              if (value % 25 == 0) {
                return Text('${value.toInt()}%'); // Show battery percentage
              }
              return SizedBox.shrink(); // Return an empty widget for other values
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Colors.blue,
          barWidth: 4,
          belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.3)),
        ),
      ],
      minX: 0, // 0 hours ago (24 hours in the past)
      maxX: 24, // 24 hours ago (current time)
      minY: 0,  // Minimum battery level
      maxY: 100, // Maximum battery level (100%)
    );
  }

}
