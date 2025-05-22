import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Student {
  final int studentId;
  final String studentName;
  final String studentSurname;
  final String studentEmail;
  final int? batchId;

  Student({
    required this.studentId,
    required this.studentName,
    required this.studentSurname,
    required this.studentEmail,
    this.batchId,
  });

  static Future<Student> fromSP() async {
    final userDetails = await SharedPreferences.getInstance();
    return Student(
      studentId: userDetails.getInt('student_id') ?? 0,
      studentName: userDetails.getString('student_name')  ?? "Unknown",
      studentSurname: userDetails.getString('student_surname')  ?? "Unknown",
      studentEmail: userDetails.getString('student_email')  ?? "Unknown",
    );
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      studentId: json['student_id'],
      studentName: json['student_name'],
      studentSurname: json['student_surname'],
      studentEmail: json['student_email']
    );
  }

  static List<Student> parseList(String responseBody) {
    final parsed = json.decode(responseBody) as List;
    return parsed.map((json) => Student.fromJson(json as Map<String, dynamic>)).toList();
  }
}
