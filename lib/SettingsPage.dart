import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _limitController;
  late TextEditingController _frequencyController;
  late TextEditingController _snoozeController;
  String _selectedTune = 'assets/alarm.mp3';
  bool isLoading = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // List of audio files in assets directory
  final List<String> _audioFiles = [
    'assets/alarm.mp3',
    'assets/a2.mp3',
    'assets/a3.mp3',
  ];

  @override
  void initState() {
    super.initState();
    _limitController = TextEditingController();
    _frequencyController = TextEditingController();
    _snoozeController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    int currentLimit = prefs.getInt('batteryLimit') ?? 100;
    int notificationFrequency = prefs.getInt('notificationFrequency') ?? 60;
    int snoozeTimes = prefs.getInt('snoozeTimes') ?? 3;
    String selectedTune = prefs.getString('selectedTune') ?? _audioFiles.first;

    setState(() {
      _limitController = TextEditingController(text: currentLimit.toString());
      _frequencyController = TextEditingController(text: notificationFrequency.toString());
      _snoozeController = TextEditingController(text: snoozeTimes.toString());
      _selectedTune = selectedTune;
    });
  }

  Future<void> _saveSettings() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    int? newLimit = int.tryParse(_limitController.text);
    int? newFrequency = int.tryParse(_frequencyController.text);
    int? newSnooze = int.tryParse(_snoozeController.text);

    if (newLimit != null && newLimit > 0 && newLimit <= 100 &&
        newFrequency != null && newFrequency > 0 &&
        newSnooze != null && newSnooze >= 0) {
      await prefs.setInt('batteryLimit', newLimit);
      await prefs.setInt('notificationFrequency', newFrequency);
      await prefs.setInt('snoozeTimes', newSnooze);
      await prefs.setString('selectedTune', _selectedTune);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Settings Saved")),
      );

      setState(() {
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invalid input!")),
      );
    }
  }

  void _playAudio(String path) async {
    await _audioPlayer.stop(); // Stop any currently playing audio
    await _audioPlayer.play(AssetSource(path));
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Container(
          height: 510,
          color: Colors.black,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _limitController,
                keyboardType: TextInputType.number,
                cursorColor: Colors.greenAccent,
                decoration: InputDecoration(
                  labelText: 'Battery Limit (%)',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.greenAccent),
                  ),
                ),
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _frequencyController,
                keyboardType: TextInputType.number,
                cursorColor: Colors.greenAccent,
                decoration: InputDecoration(
                  labelText: 'Notification Frequency (seconds)',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.greenAccent),
                  ),
                ),
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _snoozeController,
                keyboardType: TextInputType.number,
                cursorColor: Colors.greenAccent,
                decoration: InputDecoration(
                  labelText: 'Snooze Times (repeats after limit)',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.greenAccent),
                  ),
                ),
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 20),
              Text(
                'Select Tune:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Column(
                children: _audioFiles.map((file) {
                  return RadioListTile<String>(
                    title: Text(file.split('/').last, style: TextStyle(color: Colors.white)),
                    value: file,
                    groupValue: _selectedTune,
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() {
                          _selectedTune = value;
                        });
                        _playAudio(value); // Play the selected tune
                      }
                    },
                    activeColor: Colors.greenAccent,
                  );
                }).toList(),
              ),
              Spacer(),
              Center(
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  child: Text(
                    'Save',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}