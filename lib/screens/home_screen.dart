import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/routine_task.dart';
import '../services/native_bridge.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const HomeScreen({super.key, required this.onToggleTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<RoutineTask> routines = [];
  List<AppLimit> appLimits = [];
  String emergencyPin = '1234';
  int emergencyDuration = 10;

  final List> presetApps = [
    {'name': 'Instagram', 'pkg': 'com.instagram.android'},
    {'name': 'Facebook', 'pkg': 'com.facebook.katana'},
    {'name': 'YouTube', 'pkg': 'com.google.android.youtube'},
    {'name': 'TikTok', 'pkg': 'com.zhiliaoapp.musically'},
    {'name': 'X (Twitter)', 'pkg': 'com.twitter.android'},
    {'name': 'Reddit', 'pkg': 'com.reddit.frontpage'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final rStr = prefs.getString('routines') ?? '[]';
    final aStr = prefs.getString('app_limits') ?? '[]';

    setState(() {
      routines = (jsonDecode(rStr) as List)
          .map((e) => RoutineTask.fromJson(e))
          .toList();
      appLimits = (jsonDecode(aStr) as List)
          .map((e) => AppLimit.fromJson(e))
          .toList();
      emergencyPin = prefs.getString('emergency_pin') ?? '1234';
      emergencyDuration = prefs.getInt('emergency_duration') ?? 10;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'routines', jsonEncode(routines.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'app_limits', jsonEncode(appLimits.map((e) => e.toJson()).toList()));
    await prefs.setString('emergency_pin', emergencyPin);
    await prefs.setInt('emergency_duration', emergencyDuration);
  }

  String _formatMinutes(int totalMinutes) {
    final h = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final m = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _editEmergencySettingsDialog() async {
    final pinCtrl = TextEditingController(text: emergencyPin);
    int tempDuration = emergencyDuration;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Emergency Override Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Requires a 30-second cooldown + PIN on the lock screen to temporarily pause blocking for urgent work.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Emergency PIN (4-6 digits)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text('Temporary Unlock Duration: $tempDuration min'),
              Slider(
                value: tempDuration.toDouble(),
                min: 5,
                max: 30,
                divisions: 5,
                onChanged: (v) =>
                    setDialogState(() => tempDuration = v.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (pinCtrl.text.trim().length < 4) return;
                setState(() {
                  emergencyPin = pinCtrl.text.trim();
                  emergencyDuration = tempDuration;
                });
                _saveData();
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _addRoutineDialog() async {
    final titleCtrl = TextEditingController();
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 11, minute: 0);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Focus Routine'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Task Name (e.g., Study / Coding)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                          context: ctx, initialTime: startTime);
                      if (picked != null) {
                        setDialogState(() => startTime = picked);
                      }
                    },
                    child: Text('Start: ${startTime.format(ctx)}'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                          context: ctx, initialTime: endTime);
                      if (picked != null) {
                        setDialogState(() => endTime = picked);
                      }
                    },
                    child: Text('End: ${endTime.format(ctx)}'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                setState(() {
                  routines.add(RoutineTask(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleCtrl.text.trim(),
                    startMinutes: startTime.hour * 60 + startTime.minute,
                    endMinutes: endTime.hour * 60 + endTime.minute,
                  ));
                });
                _saveData();
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _addAppLimitDialog() async {
    Map<String, String> selectedApp = presetApps.first;
    int limitMin = 10;
    int cooldownMin = 15;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Social App Timer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField>(
                value: selectedApp,
                decoration: const InputDecoration(
                  labelText: 'Select App',
                  border: OutlineInputBorder(),
                ),
                items: presetApps
                    .map((app) => DropdownMenuItem(
                          value: app,
                          child: Text(app['name']!),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedApp = val);
                },
              ),
              const SizedBox(height: 16),
              Text('Allowed Usage: $limitMin min'),
              Slider(
                value: limitMin.toDouble(),
                min: 1,
                max: 60,
                divisions: 59,
                onChanged: (v) => setDialogState(() => limitMin = v.round()),
              ),
              Text('Cooldown Reset: $cooldownMin min'),
              Slider(
                value: cooldownMin.toDouble(),
                min: 5,
                max: 30,
                divisions: 25,
                onChanged: (v) =>
                    setDialogState(() => cooldownMin = v.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                setState(() {
                  appLimits.removeWhere(
                      (e) => e.packageName == selectedApp['pkg']);
                  appLimits.add(AppLimit(
                    appName: selectedApp['name']!,
                    packageName: selectedApp['pkg']!,
                    limitMinutes: limitMin,
                    cooldownMinutes: cooldownMin,
                  ));
                });
                _saveData();
                Navigator.pop(ctx);
              },
              child: const Text('Set Timer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FocusGuard',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Required Permissions',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text(
                    'Enable both permissions so FocusGuard can lock your screen during routines and block distracting apps.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: NativeBridge.openOverlaySettings,
                          child: const Text('1. Display Over Apps'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: NativeBridge.openAccessibilitySettings,
                          child: const Text('2. Accessibility'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.lock_open_outlined),
              title: const Text('Emergency Work Unlock',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  '30s wait + PIN ($emergencyPin)  •  Unlocks for $emergencyDuration mins'),
              trailing: TextButton(
                onPressed: _editEmergencySettingsDialog,
                child: const Text('Edit'),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('DAILY ROUTINE LOCKS',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              IconButton(
                  icon: const Icon(Icons.add), onPressed: _addRoutineDialog),
            ],
          ),
          if (routines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No routines set. Tap + to schedule a phone-free task.',
                  style: TextStyle(color: Colors.grey)),
            ),
          ...routines.map((r) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  title: Text(r.title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${_formatMinutes(r.startMinutes)} - ${_formatMinutes(r.endMinutes)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: r.isEnabled,
                        onChanged: (val) {
                          setState(() => r.isEnabled = val);
                          _saveData();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () {
                          setState(() => routines.remove(r));
                          _saveData();
                        },
                      ),
                    ],
                  ),
                ),
              )),

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: Main---------
            MainAxisAlignment.spaceBetween,
            children: [
              const Text('APP TIMERS & COOLDOWNS',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              IconButton(
                  icon: const Icon(Icons.add), onPressed: _addAppLimitDialog),
            ],
          ),
          if (appLimits.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                  'No app timers set. Tap + to restrict social media usage.',
                  style: TextStyle(color: Colors.grey)),
            ),
          ...appLimits.map((a) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  title: Text(a.appName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      'Limit: ${a.limitMinutes}m  •  Resets after ${a.cooldownMinutes}m'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () {
                      setState(() => appLimits.remove(a));
                      _saveData();
                    },
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
