class RoutineTask {
  final String id;
  final String title;
  final int startMinutes;
  final int endMinutes;
  bool isEnabled;

  RoutineTask({
    required this.id,
    required this.title,
    required this.startMinutes,
    required this.endMinutes,
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'isEnabled': isEnabled,
      };

  factory RoutineTask.fromJson(Map<String, dynamic> json) => RoutineTask(
        id: json['id'],
        title: json['title'],
        startMinutes: json['startMinutes'],
        endMinutes: json['endMinutes'],
        isEnabled: json['isEnabled'] ?? true,
      );
}

class AppLimit {
  final String appName;
  final String packageName;
  int limitMinutes;
  int cooldownMinutes;

  AppLimit({
    required this.appName,
    required this.packageName,
    required this.limitMinutes,
    required this.cooldownMinutes,
  });

  Map<String, dynamic> toJson() => {
        'appName': appName,
        'packageName': packageName,
        'limitMinutes': limitMinutes,
        'cooldownMinutes': cooldownMinutes,
      };

  factory AppLimit.fromJson(Map<String, dynamic> json) => AppLimit(
        appName: json['appName'],
        packageName: json['packageName'],
        limitMinutes: json['limitMinutes'],
        cooldownMinutes: json['cooldownMinutes'],
      );
}
