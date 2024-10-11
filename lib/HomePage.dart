import 'package:battery_plus/battery_plus.dart';
import 'package:battery_status/BatteryService.dart';
import 'package:battery_status/RealTimeBatteryTracker.dart';
import 'package:battery_status/SettingsPage.dart';
import 'package:battery_status/main.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final BatteryService _batteryService = BatteryService();
  int _batteryLevel = 0;
  BatteryState _batteryState = BatteryState.unknown;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _batteryService.initialize();
    _batteryService.onBatteryLevelChanged.listen((level) {
      setState(() {
        _batteryLevel = level;
      });
    });

    // Listen for battery state changes
    _batteryService.onBatteryStateChanged.listen((state) {
      setState(() {
        _batteryState = state;
      });
    });
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _batteryService.dispose();
    _tabController?.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Align(
          alignment: Alignment.center,
          child: Text('Battery Status',style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),),
        ),
      ),
      body: Column(
        children: [
          // Battery Level and Status at the top
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  '$_batteryLevel%',
                  style: TextStyle(fontSize: 30,fontWeight: FontWeight.bold,color: Colors.white),
                ),
                SizedBox(height: 8),
                Text(
                  '${_batteryState == BatteryState.charging
                      ? "Charging"
                      : _batteryState == BatteryState.full
                      ? "Full"
                      : "Discharging"}',
                  style: TextStyle(fontSize: 20,color: Colors.grey),
                ),
              ],
            ),
          ),
          // Tab Bar below battery level and status
          Container(
            padding: EdgeInsets.all(2.0),
            margin: EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Color(0xffaae48e), // Background color for the entire TabBar
              borderRadius: BorderRadius.circular(10), // Rounded corners for the container
            ),
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'Battery'),
                Tab(text: 'Settings'),
              ],
              // Customization for active tab
              indicator: BoxDecoration(
                color: Colors.black, // Active tab background color
                borderRadius: BorderRadius.circular(10), // Rounded corners for the active tab
              ),
              // Customization for inactive tabs
              labelColor: Colors.white, // Active tab text color
              unselectedLabelColor: Colors.black, // Inactive tab text color
              indicatorSize: TabBarIndicatorSize.tab, // Indicator size to fit the tab
            ),
          ),

          // TabBarView with Battery Performance and Battery Saver tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Performance Tab: Show battery usage graph
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          //  child: CircularBatteryIndicator(batteryLevel: _batteryLevel),
                          child: RealTimeBatteryTracker(),
                        ),
                      ),
                    ],
                  ),
                ),
                // Battery Saver Tab: Placeholder
                Center(
                  child: SettingsPage(),
                ),
              ],
            ),
          ),
        ],
      ),

    );
  }
}