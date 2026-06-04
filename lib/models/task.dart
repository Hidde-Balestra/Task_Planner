import 'dart:convert';

class Task {
  static int _counter = 0;

  final String id;
  String title;
  List<int> repeatDays; // 0 = Sunday ... 6 = Saturday
  Map<String, bool> completedByDate;
  DateTime creationDate;

  Task({
    String? id,
    required this.title,
    required this.repeatDays,
    Map<String, bool>? completedByDate,
    DateTime? creationDate,
  })  : id = id ?? '${DateTime.now().microsecondsSinceEpoch}_${_counter++}',
        completedByDate = completedByDate ?? {},
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
      'id': id,
      'title': title,
      'repeatDays': repeatDays,
      'creationDate': creationDate.toIso8601String(),
      'completedByDate': completedByDate,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    final id = map['id'] as String?;
    final title = map['title'] as String? ?? 'Untitled Task';
    final repeatDays = map['repeatDays'] != null
        ? List<int>.from(map['repeatDays'] as List)
        : <int>[];
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

    return Task(
      id: id,
      title: title,
      repeatDays: repeatDays,
      creationDate: creationDate,
      completedByDate: completedByDateSafe,
    );
  }

  String toJson() => json.encode(toMap());

  factory Task.fromJson(String source) =>
      Task.fromMap(json.decode(source) as Map<String, dynamic>);
}
