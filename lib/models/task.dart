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
    final title = map['title'] ?? 'Untitled Task';
    final repeatDays = map['repeatDays'] != null
        ? List<int>.from(map['repeatDays'])
        : <int>[];
    final creationDate = map['creationDate'] != null
        ? DateTime.tryParse(map['creationDate']) ?? DateTime.now()
        : DateTime.now();
    final rawCompleted = map['completedByDate'] as Map<String, dynamic>?;

    final completedByDateSafe = <String, bool>{};
    if (rawCompleted != null) {
      rawCompleted.forEach((key, value) {
        completedByDateSafe[key] = (value as bool?) ?? false;
      });
    }

    return Task(
      title: title,
      repeatDays: repeatDays,
      creationDate: creationDate,
      completedByDate: completedByDateSafe,
    );
  }




  String toJson() => json.encode(toMap());

  factory Task.fromJson(String source) =>
      Task.fromMap(json.decode(source));
}
