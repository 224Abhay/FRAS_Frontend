import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Branch {
  final int branchId;
  final String branchName;
  final int courseDuration;

  Branch({
    required this.branchId,
    required this.branchName,
    required this.courseDuration,
  });

  static Future<Branch> fromSP() async {
    final userDetails = await SharedPreferences.getInstance();
    return Branch(
      branchId: userDetails.getInt('branch_id') ?? 0,
      branchName: userDetails.getString('branch_name')  ?? "Unknown",
      courseDuration: userDetails.getInt('course_duration') ?? 0,
    );
  }

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      branchId: json['branch_id'],
      branchName: json['branch_name'],
      courseDuration: json['course_duration'],
    );
  }

  static List<Branch> parseList(String responseBody) {
    final parsed = json.decode(responseBody) as List;
    return parsed.map((json) => Branch.fromJson(json)).toList();
  }
}

class Batch {
  final int batchId;
  final int? branchId;
  final int batchOf;
  final String batch;

  Batch({
    required this.batchId,
    this.branchId,
    required this.batchOf,
    required this.batch,
  });

  static Future<Batch> fromSP() async {
    final userDetails = await SharedPreferences.getInstance();
    return Batch(
      batchId: userDetails.getInt('batch_id') ?? 0,
      batchOf: userDetails.getInt('batch_of') ?? 0,
      batch: userDetails.getString('batch')  ?? "Unknown",
    );
  }

  factory Batch.fromJson(Map<String, dynamic> json) {
    return Batch(
      batchId: json['batch_id'],
      batchOf: json['batch_of'],
      batch: json['batch'],
    );
  }

  static List<Batch> parseList(String responseBody) {
    final parsed = json.decode(responseBody) as List;
    return parsed.map((json) => Batch.fromJson(json as Map<String, dynamic>)).toList();
  }
}

class Class {
  final int classId;
  final int? batchId;
  final int year;
  final String semesterType;

  Class({
    required this.classId,
    this.batchId,
    required this.year,
    required this.semesterType,
  });

  factory Class.fromJson(Map<String, dynamic> json) {
    return Class(
      classId: json['class_id'],
      year: json['year'],
      semesterType: json['semester_type'],
    );
  }

  static List<Class> parseList(String responseBody) {
    final parsed = json.decode(responseBody) as List;
    return parsed.map((json) => Class.fromJson(json as Map<String, dynamic>)).toList();
  }

  static int getClassId(List<Class> classes, int year, String semesterType) {
    for (var classItem in classes) {
      if (classItem.year == year && classItem.semesterType == semesterType) {
        return classItem.classId;
      }
    }
    return 0;
  }
}