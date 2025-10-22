import 'dart:convert';

class Task {
  String title;
  List<int> repeatDays; // 0 = Sun ... 6 = Sat
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

  Map<String, dynamic> toMap() => {
    'title': title,
    'repeatDays': repeatDays,
    'completedByDate': completedByDate,
    'creationDate': creationDate.toIso8601String(),
  };

  String toJson() => jsonEncode(toMap());

  factory Task.fromJson(String source) {
    final map = jsonDecode(source);
    return Task(
      title: map['title'],
      repeatDays: List<int>.from(map['repeatDays']),
      completedByDate: Map<String, bool>.from(map['completedByDate'] ?? {}),
      creationDate: DateTime.parse(map['creationDate']),
    );
  }
}
