import 'dart:convert';

class Timetable {
  final int timetableId;
  final String subjectCode;
  final String startTime;
  final String endTime;
  final String roomNumber;
  final String day;

  Timetable({
    required this.timetableId,
    required this.subjectCode,
    required this.startTime,
    required this.endTime,
    required this.roomNumber,
    required this.day,
  });

  factory Timetable.fromJson(Map<String, dynamic> json) {
    return Timetable(
      timetableId: json['timetable_id'],
      subjectCode: json['subject_code'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      roomNumber: json['room_number'],
      day: json['day'],
    );
  }

  static List<Timetable> parseList(String responseBody) {
    final parsed = json.decode(responseBody) as List;
    return parsed.map((json) => Timetable.fromJson(json as Map<String, dynamic>)).toList();
  }
}

class STimetable extends Timetable {
  final String subjectName;
  final String teacherName;
  final String teacherSurname;

  STimetable({
    required super.timetableId,
    required super.subjectCode,
    required super.startTime,
    required super.endTime,
    required super.roomNumber,
    required super.day,
    required this.subjectName,
    required this.teacherName,
    required this.teacherSurname,
  });

  factory STimetable.fromJson(Map<String, dynamic> json) {
    return STimetable(
      timetableId: json['timetable_id'],
      subjectCode: json['subject_code'],
      subjectName: json['subject_name'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      roomNumber: json['room_number'],
      day: json['day'],
      teacherName: json['teacher_name'],
      teacherSurname: json['teacher_surname'],
    );
  }

  static List<STimetable> parseList(String responseBody) {
    final parsed = json.decode(responseBody) as List;
    return parsed.map((json) => STimetable.fromJson(json as Map<String, dynamic>)).toList();
  }
}

class TTimetable extends Timetable {
  final String subjectName;
  final int batchId;

  TTimetable({
    required super.timetableId,
    required super.subjectCode,
    required super.startTime,
    required super.endTime,
    required super.roomNumber,
    required super.day,
    required this.subjectName,
    required this.batchId,
  });

  factory TTimetable.fromJson(Map<String, dynamic> json) {
    return TTimetable(
      timetableId: json['timetable_id'],
      subjectCode: json['subject_code'],
      subjectName: json['subject_name'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      roomNumber: json['room_number'],
      day: "",
      batchId: json['batch_id'],
    );
  }

  static List<TTimetable> parseList(String responseBody) {
    final parsed = json.decode(responseBody) as List;
    return parsed.map((json) => TTimetable.fromJson(json as Map<String, dynamic>)).toList();
  }
}

class Attendance {
  final int? studentId;
  final int timetableId;
  final int? status;
  final String? roomNumber;
  final String date;

  Attendance({
    this.studentId,
    required this.timetableId,
    required this.status,
    required this.roomNumber,
    required this.date,
  });

  factory Attendance.fromJson(Map<String, dynamic> map) {
    return Attendance(
      studentId: map['student_id'],
      timetableId: map['timetable_id'],
      status: map['status'],
      roomNumber: map['room_number'],
      date: map['date'],
    );
  }

  static List<Attendance> parseList(String responseBody) {
    final parsed = json.decode(responseBody) as List;
    return parsed.map((json) => Attendance.fromJson(json as Map<String, dynamic>)).toList();
  }
}

class AttendanceStats extends Attendance {
  final String startTime;
  final String endTime;
  final int? classId;

  // Constructor for AttendanceStats that passes parameters to the parent class (Attendance)
  AttendanceStats({
    required super.timetableId,
    required int super.status,
    required super.date,
    required this.startTime,
    required this.endTime,
    String? roomNumber,  // Optional roomNumber, inherited from Attendance
    this.classId,        // Optional classId
  }) : super(
    roomNumber: roomNumber ?? '',
  );

  // Factory constructor to create an AttendanceStats object from a Map (e.g., JSON)
  factory AttendanceStats.fromJson(Map<String, dynamic> map) {
    return AttendanceStats(
      timetableId: map['timetable_id'],
      status: map['status'],
      date: map['date'],
      startTime: map['start_time'],
      endTime: map['end_time'],
      roomNumber: map['room_number'],  // Optional, it could be null
      classId: map['class_id'],        // Optional
    );
  }

  // Override toString() method to include additional fields specific to AttendanceStats
  @override
  String toString() {
    return 'AttendanceStats(timetableId: $timetableId, status: $status, date: $date, roomNumber: $roomNumber, startTime: $startTime, endTime: $endTime, classId: $classId)';
  }

  // Optional: You can also override methods from Attendance if needed, such as the `parseList` method
  static List<AttendanceStats> parseList(String responseBody) {
    final parsed = json.decode(responseBody) as List;
    return parsed.map((json) => AttendanceStats.fromJson(json as Map<String, dynamic>)).toList();
  }
}

