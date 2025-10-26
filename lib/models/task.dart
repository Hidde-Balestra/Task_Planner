import 'dart:convert';

class Task {
  String title;
  List<int> repeatDays; // 0 = Sunday ... 6 = Saturday
  Map<String, bool> completedByDate;
  DateTime creationDate;

  Task({
    required this.title,
    required this.repeatDays,
    Map<String, bool>? completedByDate,
    DateTime? creationDate,
  })  : completedByDate = completedByDate ?? {},
        creationDate = creationDate ?? DateTime.now();

  bool isCompleted(DateTime date) {
    final key = _dateKey(date);
    return completedByDate[key] ?? false;
  }

  void toggleCompletion(DateTime date) {
    final key = _dateKey(date);
    completedByDate[key] = !(completedByDate[key] ?? false);
  }

  String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'repeatDays': repeatDays,
      'creationDate': creationDate.toIso8601String(),
      'completedByDate': completedByDate,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    final title = map['title'] != null ? map['title'].toString() : 'Untitled Task';

    final repeatDaysRaw = map['repeatDays'];
    final repeatDays = (repeatDaysRaw is List)
        ? repeatDaysRaw.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0).toList()
        : <int>[];

    DateTime creationDate;
    if (map['creationDate'] != null) {
      creationDate = DateTime.tryParse(map['creationDate'].toString()) ?? DateTime.now();
    } else {
      creationDate = DateTime.now();
    }

    final rawCompleted = map['completedByDate'];
    final completedByDate = (rawCompleted is Map)
        ? rawCompleted.map((key, value) => MapEntry(key.toString(), value == true))
        : <String, bool>{};

    return Task(
      title: title,
      repeatDays: repeatDays,
      creationDate: creationDate,
      completedByDate: completedByDate,
    );
  }


  String toJson() => json.encode(toMap());

  factory Task.fromJson(String source) =>
      Task.fromMap(json.decode(source));
}
