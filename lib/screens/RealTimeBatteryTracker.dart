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

    _timer = Timer.periodic(Duration(minutes: 5), (timer) {
      _getBatteryLevel();
    });


    _getBatteryLevel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _getBatteryLevel() async {
    final batteryLevel = await _battery.batteryLevel;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    print('Battery level fetched: $batteryLevel%');


    _batteryHistory.add({'timestamp': timestamp, 'level': batteryLevel});


    final twentyFourHoursAgo = DateTime.now().subtract(Duration(hours: 24)).millisecondsSinceEpoch;
    _batteryHistory.removeWhere((entry) => entry['timestamp'] < twentyFourHoursAgo);

    print('Battery history: $_batteryHistory'); // Debugging: Check battery history


    await _saveBatteryHistory();


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
      double hoursAgo = (DateTime.now().millisecondsSinceEpoch - entry['timestamp']) / (1000 * 3600);
      double level = entry['level'].toDouble();
      spots.add(FlSpot(24 - hoursAgo, level));
    }

    return LineChartData(
      gridData: FlGridData(show: true),
      borderData: FlBorderData(show: true),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: 3,
            getTitlesWidget: (value, _) {

              if (value % 3 == 0) {
                int hoursAgo = (24 - value).toInt();
                return Text('${hoursAgo}h');
              }
              return SizedBox.shrink();
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: 25,
            getTitlesWidget: (value, _) {
              if (value % 25 == 0) {
                return Text('${value.toInt()}%');
              }
              return SizedBox.shrink();
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
      minX: 0,
      maxX: 24,
      minY: 0,
      maxY: 100,
    );
  }

}
