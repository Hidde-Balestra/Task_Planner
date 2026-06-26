import 'dart:convert';

enum Priority { low, medium, high }

class Task {
  static int _counter = 0;

  final String id;
  String title;
  List<int> repeatDays; // 0 = Sunday ... 6 = Saturday
  int repeatIntervalDays; // 0 = off; >0 = repeat every N days from creationDate
  Priority priority;
  Map<String, bool> completedByDate;
  DateTime creationDate;
  // Maps original date key → postponed-to date key
  Map<String, String> postponedDates;
  // "HH:mm" deadline time; null means no deadline
  String? dueTime;

  Task({
    String? id,
    required this.title,
    required this.repeatDays,
    this.repeatIntervalDays = 0,
    this.priority = Priority.low,
    Map<String, bool>? completedByDate,
    DateTime? creationDate,
    Map<String, String>? postponedDates,
    this.dueTime,
  })  : id = id ?? '${DateTime.now().microsecondsSinceEpoch}_${_counter++}',
        completedByDate = completedByDate ?? {},
        creationDate = creationDate ?? DateTime.now(),
        postponedDates = postponedDates ?? {};

  bool isCompleted(DateTime date) {
    final key = _dateKey(date);
    return completedByDate[key] ?? false;
  }

  void toggleCompletion(DateTime date) {
    final key = _dateKey(date);
    completedByDate[key] = !(completedByDate[key] ?? false);
  }

  bool isPostponedOnDate(DateTime date) =>
      postponedDates.containsKey(_dateKey(date));

  void postponeTo(DateTime fromDate, DateTime toDate) {
    postponedDates[_dateKey(fromDate)] = _dateKey(toDate);
  }

  String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'repeatDays': repeatDays,
      'repeatIntervalDays': repeatIntervalDays,
      'priority': priority.name,
      'creationDate': creationDate.toIso8601String(),
      'completedByDate': completedByDate,
      'postponedDates': postponedDates,
      if (dueTime != null) 'dueTime': dueTime,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    final id = map['id'] as String?;
    final title = map['title'] as String? ?? 'Untitled Task';
    final repeatDays = map['repeatDays'] != null
        ? List<int>.from(map['repeatDays'] as List)
        : <int>[];
    final repeatIntervalDays = (map['repeatIntervalDays'] as num?)?.toInt() ?? 0;
    final priority = Priority.values.firstWhere(
      (p) => p.name == map['priority'],
      orElse: () => Priority.low,
    );
    final creationDate = map['creationDate'] != null
        ? DateTime.tryParse(map['creationDate'] as String) ?? DateTime.now()
        : DateTime.now();
    final rawCompleted = map['completedByDate'];

    final completedByDateSafe = <String, bool>{};
    if (rawCompleted is Map) {
      rawCompleted.forEach((key, value) {
        completedByDateSafe[key.toString()] = value == true;
      });
    }

    final rawPostponed = map['postponedDates'];
    final postponedDatesSafe = <String, String>{};
    if (rawPostponed is Map) {
      rawPostponed.forEach((key, value) {
        if (value != null) {
          postponedDatesSafe[key.toString()] = value.toString();
        }
      });
    }

    final dueTime = map['dueTime'] as String?;

    return Task(
      id: id,
      title: title,
      repeatDays: repeatDays,
      repeatIntervalDays: repeatIntervalDays,
      priority: priority,
      creationDate: creationDate,
      completedByDate: completedByDateSafe,
      postponedDates: postponedDatesSafe,
      dueTime: dueTime,
    );
  }

  String toJson() => json.encode(toMap());

  factory Task.fromJson(String source) =>
      Task.fromMap(json.decode(source) as Map<String, dynamic>);
}
