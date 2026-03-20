import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:mingym/services/firestore_service.dart';
import 'package:mingym/managers/active_workout_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mingym/screens/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isKg = true;
  int _defaultRestTime = 120;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _defaultRestTime = prefs.getInt('default_rest_time') ?? 120;
      _isKg = prefs.getBool('use_kg') ?? true;
    });
  }

  Future<void> _updateRestTime(int? newValue) async {
    if (newValue == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('default_rest_time', newValue);
    ActiveWorkoutManager().defaultRestSeconds = newValue;
    setState(() => _defaultRestTime = newValue);
  }

  Future<void> _exportCSV() async {
    setState(() => _isExporting = true);
    try {
      final history = await FirestoreService().getWorkoutHistoryStream().first;
      List<List<dynamic>> rows = [
        ["Date", "Workout Title", "Duration (min)", "Total Volume", "Exercise", "Set", "Weight", "Reps", "RPE"]
      ];

      for (var log in history) {
        for (var ex in log.exercises) {
          for (int i = 0; i < ex.loggedSets.length; i++) {
            var set = ex.loggedSets[i];
            if (set.isCompleted) {
              rows.add([
                log.date.toIso8601String().split('T')[0], 
                log.title, log.durationMinutes, log.totalVolume,
                ex.name, i + 1, set.weight, set.reps, set.rpe ?? ''
              ]);
            }
          }
        }
      }

      String csvData = const ListToCsvConverter().convert(rows);
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/mingym_export.csv";
      final file = File(path);
      await file.writeAsString(csvData);

      await Share.shareXFiles([XFile(path)], text: 'My mingym Workout Data');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final isAnonymous = user?.isAnonymous ?? true;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 35, 16, 0),
          children: [
            const Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            const Text('Account', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              color: Colors.grey.shade900,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: isAnonymous ? Colors.grey.shade800 : Colors.blue.withValues(alpha: 0.2),
                          child: Icon(isAnonymous ? Icons.person_outline : Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAnonymous ? 'Guest User' : 'Secured Account',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              if (!isAnonymous)
                                Text(user?.email ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isAnonymous) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Create an account to permanently save your workout data and access it on other devices.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                      width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (context) => const LoginScreen(isLinking: true))
                            ).then((_) => setState(() {})); 
                          },
                          icon: const Icon(Icons.email_outlined, size: 20),
                          label: const Text('Sign Up with Email', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white, backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                          },
                          icon: const Icon(Icons.logout, size: 20, color: Colors.redAccent),
                          label: const Text('Sign Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text('Preferences', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              color: Colors.grey.shade900,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Display Weight in', style: TextStyle(color: Colors.white)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'lbs', 
                          style: TextStyle(color: !_isKg ? Colors.blueAccent : Colors.grey, fontWeight: !_isKg ? FontWeight.bold : FontWeight.normal)
                        ),
                        Switch(
                          value: _isKg,
                          activeThumbColor: Colors.blueAccent,
                          inactiveThumbColor: Colors.blueAccent,
                          inactiveTrackColor: Colors.black.withValues(alpha: 0.3),
                          onChanged: (val) async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('use_kg', val);
                            ActiveWorkoutManager().isKg = val;
                            ActiveWorkoutManager().updateUI();
                            setState(() => _isKg = val);
                          },
                        ),
                        Text(
                          'kg', 
                          style: TextStyle(color: _isKg ? Colors.blueAccent : Colors.grey, fontWeight: _isKg ? FontWeight.bold : FontWeight.normal)
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  ListTile(
                    title: const Text('Default Rest Timer', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Starts automatically when completing a set', style: TextStyle(color: Colors.grey)),
                    trailing: DropdownButton<int>(
                      value: _defaultRestTime,
                      dropdownColor: Colors.grey.shade800,
                      style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16),
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 60, child: Text('1:00')),
                        DropdownMenuItem(value: 90, child: Text('1:30')),
                        DropdownMenuItem(value: 120, child: Text('2:00')),
                        DropdownMenuItem(value: 150, child: Text('2:30')),
                        DropdownMenuItem(value: 180, child: Text('3:00')),
                        DropdownMenuItem(value: 240, child: Text('4:00')),
                        DropdownMenuItem(value: 300, child: Text('5:00')),
                      ],
                      onChanged: _updateRestTime,
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  ListTile(
                    title: const Text('Change Timer Sound', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Pick a sound from your device settings', style: TextStyle(color: Colors.grey)),
                    trailing: const Icon(Icons.open_in_new, color: Colors.blueAccent, size: 20),
                    onTap: () => openAppSettings(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text('Data', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              color: Colors.grey.shade900,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    leading: _isExporting 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent))
                      : const Icon(Icons.download, color: Colors.white),
                    title: const Text('Export Data to CSV', style: TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: _isExporting ? null : _exportCSV,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            
            const Center(
              child: Text(
                'mingym v1.0.0',
                style: TextStyle(color: Colors.white24, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}