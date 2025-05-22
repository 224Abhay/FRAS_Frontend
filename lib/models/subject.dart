import 'dart:convert';

class Subject {
  final String subjectCode;
  final String subjectName;

  Subject({
    required this.subjectCode,
    required this.subjectName,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      subjectCode: json['subject_code'],
      subjectName: json['subject_name'],
    );
  }

  static List<Subject> parseList(String responseBody) {
    final parsed = json.decode(responseBody) as List;
    return parsed.map((json) => Subject.fromJson(json)).toList();
  }

  static String getSubjectName(String subjectCode, List<Subject> subjects) {
    for (var subject in subjects) {
      if (subject.subjectCode == subjectCode) {
        return subject.subjectName;
      }
    }
    return 'Subject not found';
  }

}

class SubjectStats extends Subject {
  final int? attended;
  final int? total;

  SubjectStats({
    required super.subjectCode,
    required super.subjectName,
    required this.attended,
    required this.total,
  });

  factory SubjectStats.fromJson(Map<String, dynamic> json) {
    return SubjectStats(
      subjectCode: json['subject_code'],
      subjectName: json['subject_name'],
      attended: json['attended'],
      total: json['total'],
    );
  }

  static List<SubjectStats> parseList(String responseBody) {
    final parsed = json.decode(responseBody) as List;
    return parsed.map((json) => SubjectStats.fromJson(json)).toList();
  }
}
