import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

String baseUrl = "http://192.168.137.1:5000";
String? accessToken;
var client = http.Client();

Future<void> init() async {
  await _getAccessToken();
}

Future<void> _getAccessToken() async {
  SharedPreferences credentials = await SharedPreferences.getInstance();
  accessToken = credentials.getString('access_token');
}

Future<http.Response> postApiRequest(String endpoint, dynamic body) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: json.encode(body),
    );
    return response;
  } on SocketException catch (_) {
    return http.Response(
        '{"message": "Network error: Server down. Please try again after some time."}',
        503);
  } catch (e) {
    return http.Response('{"message": "Unexpected error: $e"}', 500);
  }
}

Future<http.Response> getApiRequest(String endpoint) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    return response;
  } on SocketException catch (_) {
    return http.Response(
        '{"message": "Network error: Server down. Please try again later."}',
        503);
  } catch (e) {
    return http.Response('{"message": "Unexpected error: $e"}', 500);
  }
}

Future<http.Response> putApiRequest(String endpoint, dynamic body) async {
  try {
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: json.encode(body),
    );
    return response;
  } on SocketException catch (_) {
    return http.Response(
        '{"message": "Network error: Server down. Please try again later."}',
        503);
  } catch (e) {
    return http.Response('{"message": "Unexpected error: $e"}', 500);
  }
}

Future<http.Response> deleteApiRequest(String endpoint,{Map<String, dynamic>? body}) async {
  try {
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: body != null ? json.encode(body) : null,
    );
    return response;
  } on SocketException catch (_) {
    return http.Response(
        '{"message": "Network error: Server down. Please try again later."}',
        503);
  } catch (e) {
    return http.Response('{"message": "Unexpected error: $e"}', 500);
  }
}

// Student API calls
// Future<List<Student>> fetchStudents() async {
//   final response = await http.get(Uri.parse('$baseUrl/students'));
//   if (response.statusCode == 200) {
//     List<dynamic> jsonData = json.decode(response.body);
//     return jsonData.map((data) => Student.fromJson(data)).toList();
//   } else {
//     throw Exception('Failed to load students');
//   }
// }
//
// Future<void> addStudent(Student student) async {
//   final response = await http.post(
//     Uri.parse('$baseUrl/students'),
//     headers: <String, String>{
//       'Content-Type': 'application/json; charset=UTF-8',
//     },
//     body: jsonEncode(student.toJson()),
//   );
//   if (response.statusCode != 201) {
//     throw Exception('Failed to add student');
//   }
// }
//
// // Teacher API calls
// Future<List<Teacher>> fetchTeachers() async {
//   final response = await http.get(Uri.parse('$baseUrl/teachers'));
//   if (response.statusCode == 200) {
//     List<dynamic> jsonData = json.decode(response.body);
//     return jsonData.map((data) => Teacher.fromJson(data)).toList();
//   } else {
//     throw Exception('Failed to load teachers');
//   }
// }
//
// Future<void> addTeacher(Teacher teacher) async {
//   final response = await http.post(
//     Uri.parse('$baseUrl/teachers'),
//     headers: <String, String>{
//       'Content-Type': 'application/json; charset=UTF-8',
//     },
//     body: jsonEncode(teacher.toJson()),
//   );
//   if (response.statusCode != 201) {
//     throw Exception('Failed to add teacher');
//   }
// }
//
// // Class API calls
// Future<List<Class>> fetchClasses() async {
//   final response = await http.get(Uri.parse('$baseUrl/classes'));
//   if (response.statusCode == 200) {
//     List<dynamic> jsonData = json.decode(response.body);
//     return jsonData.map((data) => Class.fromJson(data)).toList();
//   } else {
//     throw Exception('Failed to load classes');
//   }
// }
//
// Future<void> addClass(Class classObj) async {
//   final response = await http.post(
//     Uri.parse('$baseUrl/classes'),
//     headers: <String, String>{
//       'Content-Type': 'application/json; charset=UTF-8',
//     },
//     body: jsonEncode(classObj.toJson()),
//   );
//   if (response.statusCode != 201) {
//     throw Exception('Failed to add class');
//   }
// }
//
// // Subject API calls
// // Future<List<Subject>> fetchSubjects() async {
// //   final response = await http.get(Uri.parse('$baseUrl/subjects'));
// //   if (response.statusCode == 200) {
// //     List<dynamic> jsonData = json.decode(response.body);
// //     return jsonData.map((data) => Subject.fromJson(data)).toList();
// //   } else {
// //     throw Exception('Failed to load subjects');
// //   }
// // }
// //
// // Future<void> addSubject(Subject subject) async {
// //   final response = await http.post(
// //     Uri.parse('$baseUrl/subjects'),
// //     headers: <String, String>{
// //       'Content-Type': 'application/json; charset=UTF-8',
// //     },
// //     body: jsonEncode(subject.toJson()),
// //   );
// //   if (response.statusCode != 201) {
// //     throw Exception('Failed to add subject');
// //   }
// // }
//
// // Timetable API calls
// Future<List<Timetable>> fetchTimetables() async {
//   final response = await http.get(Uri.parse('$baseUrl/timetables'));
//   if (response.statusCode == 200) {
//     List<dynamic> jsonData = json.decode(response.body);
//     return jsonData.map((data) => Timetable.fromJson(data)).toList();
//   } else {
//     throw Exception('Failed to load timetables');
//   }
// }
//
// Future<void> addTimetable(Timetable timetable) async {
//   final response = await http.post(
//     Uri.parse('$baseUrl/timetables'),
//     headers: <String, String>{
//       'Content-Type': 'application/json; charset=UTF-8',
//     },
//     body: jsonEncode(timetable.toJson()),
//   );
//   if (response.statusCode != 201) {
//     throw Exception('Failed to add timetable');
//   }
// }
