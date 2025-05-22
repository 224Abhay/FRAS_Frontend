import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Teacher {
  final int teacherId;
  final String teacherName;
  final String teacherSurname;
  final String teacherEmail;

  Teacher({
    required this.teacherId,
    required this.teacherName,
    required this.teacherSurname,
    required this.teacherEmail,
  });

  static Future<Teacher> fromSP() async {
    final userDetails = await SharedPreferences.getInstance();
    return Teacher(
      teacherId: userDetails.getInt('teacher_id') ?? 0,
      teacherName: userDetails.getString('teacher_name')  ?? "Unknown",
      teacherSurname: userDetails.getString('teacher_surname')  ?? "Unknown",
      teacherEmail: userDetails.getString('teacher_email')  ?? "Unknown",
    );
  }

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      teacherId: json['teacher_id'],
      teacherName: json['teacher_name'],
      teacherSurname: json['teacher_surname'],
      teacherEmail: json['teacher_email'],
    );
  }

  static List<Teacher> parseList(String responseBody) {
    final parsed = json.decode(responseBody) as List;
    return parsed.map((json) => Teacher.fromJson(json as Map<String, dynamic>)).toList();
  }

  static String getTeacherName(int teacherId, List<Teacher> teachers) {
    for (var teacher in teachers) {
      if (teacher.teacherId == teacherId) {
        return '${teacher.teacherName} ${teacher.teacherSurname}';
      }
    }
    return 'Teacher not found';
  }
}

class TeacherSubject {
  final int classId;
  final String subjectCode;
  final int batchId;
  final int year;
  final String semesterType;
  final String batch;
  final int branchId;
  final String branchName;
  final int courseDuration;
  final int batchOf;

  TeacherSubject({
    required this.classId,
    required this.subjectCode,
    required this.batchId,
    required this.year,
    required this.semesterType,
    required this.batch,
    required this.branchId,
    required this.branchName,
    required this.courseDuration,
    required this.batchOf,
  });

  factory TeacherSubject.fromJson(Map<String, dynamic> json) {
    return TeacherSubject(
      classId: json['class_id'],
      subjectCode: json['subject_code'],
      batchId: json['batch_id'],
      year: json['year'],
      semesterType: json['semester_type'],
      batch: json['batch'],
      branchId: json['branch_id'],
      branchName: json['branch_name'],
      courseDuration: json['course_duration'],
      batchOf: json['batch_of'],
    );
  }

  static List<TeacherSubject> parseList(String responseBody) {
    final parsed = json.decode(responseBody) as List;
    return parsed.map((json) => TeacherSubject.fromJson(json as Map<String, dynamic>)).toList();
  }
}

class ClassSubject {
  final int classId;
  final String subjectCode;
  final int teacherId;

  ClassSubject({
    required this.subjectCode,
    required this.teacherId,
    required this.classId,
  });

  factory ClassSubject.fromJson(Map<String, dynamic> json) {
    return ClassSubject(
      subjectCode: json['subject_code'],
      teacherId: json['teacher_id'],
      classId: json['class_id'],
    );
  }
  static List<ClassSubject> parseList(String responseBody) {
    final parsed = json.decode(responseBody) as List;
    return parsed.map((json) => ClassSubject.fromJson(json as Map<String, dynamic>)).toList();
  }
}