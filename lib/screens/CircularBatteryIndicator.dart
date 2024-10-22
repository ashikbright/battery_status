import 'package:flutter/material.dart';

class CircularBatteryIndicator extends StatelessWidget {
  final int batteryLevel;

  const CircularBatteryIndicator({Key? key, required this.batteryLevel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Circular background
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[800],
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10.0,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
            ),
            // Circular progress indicator
            SizedBox(
              width: 180,
              height: 180,
              child: CircularProgressIndicator(
                value: batteryLevel / 100, // Scale the battery level
                strokeWidth: 10,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(_getBatteryColor(batteryLevel)),
              ),
            ),
            // Battery percentage text
            Text(
              '$batteryLevel%',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Function to determine the color based on battery level
  Color _getBatteryColor(int level) {
    if (level > 75) {
      return Colors.green; // High battery
    } else if (level > 50) {
      return Colors.yellow; // Medium battery
    } else if (level > 25) {
      return Colors.orange; // Low battery
    } else {
      return Colors.red; // Critical battery
    }
  }
}

// class SettingsPage extends StatefulWidget {
//   @override
//   _SettingsPageState createState() => _SettingsPageState();
// }
//
// class _SettingsPageState extends State<SettingsPage> {
//   late TextEditingController _limitController;
//   late TextEditingController _frequencyController;
//   late TextEditingController _snoozeController;
//   String _selectedTune = 'assets/alarm.mp3';
//   bool isLoading = false; // Add a loading state to handle the save operation
//   final BatteryService _batteryService = BatteryService();
//
//   @override
//   void initState() {
//     super.initState();
//     _limitController = TextEditingController();
//     _frequencyController = TextEditingController();
//     _snoozeController = TextEditingController();
//     _loadSettings();
//   }
//
//   Future<void> _loadSettings() async {
//     final prefs = await SharedPreferences.getInstance();
//     int currentLimit = prefs.getInt('batteryLimit') ?? BatteryService.batteryLimit;
//     int notificationFrequency = prefs.getInt('notificationFrequency') ?? BatteryService.notificationFrequency;
//     int snoozeTimes = prefs.getInt('snoozeTimes') ?? BatteryService.snoozeTimes;
//     String selectedTune = prefs.getString('selectedTune') ?? 'assets/alarm.mp3';
//
//     setState(() {
//       _limitController = TextEditingController(text: currentLimit.toString());
//       _frequencyController = TextEditingController(text: notificationFrequency.toString());
//       _snoozeController = TextEditingController(text: snoozeTimes.toString());
//       _selectedTune = selectedTune;
//     });
//   }
//
//   Future<void> _saveSettings() async {
//     setState(() {
//       isLoading = true; // Set loading to true when saving starts
//     });
//
//     final prefs = await SharedPreferences.getInstance();
//     int? newLimit = int.tryParse(_limitController.text);
//     int? newFrequency = int.tryParse(_frequencyController.text);
//     int? newSnooze = int.tryParse(_snoozeController.text);
//
//     if (newLimit != null && newLimit > 0 && newLimit <= 100 &&
//         newFrequency != null && newFrequency > 0 &&
//         newSnooze != null && newSnooze >= 0) {
//
//       // Save settings to SharedPreferences
//       await prefs.setInt('batteryLimit', newLimit);
//       await prefs.setInt('notificationFrequency', newFrequency);
//       await prefs.setInt('snoozeTimes', newSnooze);
//       await prefs.setString('selectedTune', _selectedTune);
//
//       // Update battery service settings
//       _batteryService.updateSettings(newLimit, newFrequency, newSnooze, _selectedTune);
//
//       // Show success message
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Settings Saved")));
//
//       setState(() {
//         isLoading = false; // Set loading to false once saving is complete
//       });
//
//       // Optionally, you can refresh any necessary data here if needed
//     } else {
//       setState(() {
//         isLoading = false; // Set loading to false if validation fails
//       });
//
//       // Show error message if validation fails
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Invalid input!")));
//     }
//   }
//
//
//   @override
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: isLoading
//           ? Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//     child:
//       Container(
//         height: 510,
//         color: Colors.black, // Set background color to black
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             TextField(
//               controller: _limitController,
//               keyboardType: TextInputType.number,
//               cursorColor: Colors.greenAccent,
//               decoration: InputDecoration(
//                 labelText: 'Battery Limit (%)',
//                 labelStyle: TextStyle(color: Colors.white), // Change label text color
//                 enabledBorder: OutlineInputBorder(
//                   borderSide: BorderSide(color: Colors.grey), // Outline color for enabled state
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderSide: BorderSide(color: Colors.greenAccent), // Outline color for focused state
//                 ),
//               ),
//               style: TextStyle(color: Colors.white), // Change text color to white
//             ),
//             SizedBox(height: 10),
//             TextField(
//               controller: _frequencyController,
//               keyboardType: TextInputType.number,
//               cursorColor: Colors.greenAccent,
//               decoration: InputDecoration(
//                 labelText: 'Notification Frequency (seconds)',
//                 labelStyle: TextStyle(color: Colors.white),
//                 enabledBorder: OutlineInputBorder(
//                   borderSide: BorderSide(color: Colors.grey),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderSide: BorderSide(color: Colors.greenAccent),
//                 ),
//               ),
//               style: TextStyle(color: Colors.white),
//             ),
//             SizedBox(height: 10),
//             TextField(
//               controller: _snoozeController,
//               keyboardType: TextInputType.number,
//               cursorColor: Colors.greenAccent,
//               decoration: InputDecoration(
//                 labelText: 'Snooze Times (repeats after limit)',
//                 labelStyle: TextStyle(color: Colors.white),
//                 enabledBorder: OutlineInputBorder(
//                   borderSide: BorderSide(color: Colors.grey),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderSide: BorderSide(color: Colors.greenAccent),
//                 ),
//               ),
//               style: TextStyle(color: Colors.white),
//             ),
//             SizedBox(height: 20),
//             Text(
//               'Selected Tune:',
//               style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white), // Change color to white
//             ),
//             Padding(
//               padding: const EdgeInsets.symmetric(vertical: 8.0),
//               child: Text(
//                 _selectedTune.isNotEmpty ? _selectedTune : 'No tune selected',
//                 style: TextStyle(
//                   color: _selectedTune.isNotEmpty ? Colors.greenAccent : Colors.redAccent,
//                 ),
//               ),
//             ),
//             TextButton.icon(
//               icon: Icon(Icons.music_note, color: Colors.white), // Change icon color to white
//               onPressed: () async {
//                 FilePickerResult? result = await FilePicker.platform.pickFiles(
//                   type: FileType.audio,
//                 );
//                 if (result != null) {
//                   String? path = result.files.single.path;
//                   if (path != null) {
//                     setState(() {
//                       _selectedTune = path;
//                     });
//                   }
//                 }
//               },
//               label: Text('Choose File', style: TextStyle(color: Colors.white)), // Change label color to white
//             ),
//             Spacer(),
//             Center(
//               child: ElevatedButton(
//                 onPressed: _saveSettings,
//                 child: Text('Save',style: TextStyle(color: Colors.white),),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.green, // Set button background color
//                   padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12), // Adjust padding
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//       ),
//     );
//   }
//
// }







// class BatteryIndicator extends StatelessWidget {
//   final int batteryLevel;
//
//   const BatteryIndicator({Key? key, required this.batteryLevel}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Stack(
//         alignment: Alignment.bottomCenter,
//         children: [
//           // Cylinder outline with shadow for a modern look
//           Container(
//             width: 60,
//             height: 220,
//             decoration: BoxDecoration(
//               color: Colors.grey[800],
//               borderRadius: BorderRadius.circular(30),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.3),
//                   blurRadius: 10.0,
//                   offset: Offset(0, 5),
//                 ),
//               ],
//             ),
//           ),
//           // Filled part representing battery level with gradient color
//           Container(
//             width: 60,
//             height: _getCylinderHeight(batteryLevel),
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [_getBatteryColor(batteryLevel), Colors.black],
//                 begin: Alignment.bottomCenter,
//                 end: Alignment.topCenter,
//               ),
//               borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // Function to calculate height based on battery level (0-100)
//   double _getCylinderHeight(int level) {
//     if (level < 0) level = 0;
//     if (level > 100) level = 100;
//     return (level / 100) * 200; // Scale height between 0 and 200
//   }
//
//   // Function to determine the color based on battery level
//   Color _getBatteryColor(int level) {
//     if (level > 75) {
//       return Colors.green; // High battery
//     } else if (level > 50) {
//       return Colors.yellow; // Medium battery
//     } else if (level > 25) {
//       return Colors.orange; // Low battery
//     } else {
//       return Colors.red; // Critical battery
//     }
//   }
// }






