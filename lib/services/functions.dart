import "dart:convert";

import "package:flutter/material.dart";
import "package:identify_fras/services/api_service.dart" as api_service;
import "package:shared_preferences/shared_preferences.dart";

String getInitials(String name, String surname) {
  return name[0]+surname[0];
}

String getSuffix(int num) {
  String suffix = 'th';
  if (num == 1) {
    suffix = 'st';
  } else if (num == 2) {
    suffix = 'nd';
  } else if (num == 3) {
    suffix = 'rd';
  }
  return '$num$suffix';
}

String formatToMySQLTime(double hour) {
  int h = hour.toInt();
  String formattedHour = h < 10 ? '0$h' : '$h';
  return '$formattedHour:00:00';
}

String formatTimeToMySQL(TimeOfDay time) {
  final hours = time.hour.toString().padLeft(2, '0');
  final minutes = time.minute.toString().padLeft(2, '0');
  return '$hours:$minutes:00'; // Example: '08:30:00'
}

String formatHour(double hour) {
  int h = hour.toInt();
  return h > 12 ? '${h - 12} PM' : '$h AM';
}

String formatTime(String time) {
  // Split the input time string into its components
  List<String> timeParts = time.split(':');

  // Parse hours, minutes, and seconds
  int hour = int.parse(timeParts[0]);
  String minute = timeParts[1];

  // Determine AM or PM
  String period = hour >= 12 ? 'PM' : 'AM';

  // Convert hour to 12-hour format
  int formattedHour = hour % 12;
  formattedHour = formattedHour == 0 ? 12 : formattedHour; // Handle midnight (00:00)

  // Format the output string with leading zero for hour and minute
  return '${formattedHour.toString().padLeft(2, '0')}:$minute $period';
}

String formatDate(DateTime date) {
  return date.toString().substring(0,11);
}

DateTime getStartOfWeek(DateTime date) {
  return date.subtract(Duration(days: date.weekday - 1));
}

Future<String?> checkHoliday(DateTime date) async {
  final int year = date.year;
  final String dateStr = date.toIso8601String().split('T').first;
  final prefs = await SharedPreferences.getInstance();

  String? holidaysJson = prefs.getString('holidays_$year');

  Map<String, String> holidays;

  if (holidaysJson != null) {
    // Load holidays from SharedPreferences
    final Map<String, dynamic> holidaysData = json.decode(holidaysJson);
    holidays = holidaysData.map((key, value) => MapEntry(key, value as String));
  } else {
    // If not in SharedPreferences, make API request
    final response = await api_service.getApiRequest('/get_holidays?year=$year');

    if (response.statusCode == 200) {
      // Parse and save the holidays to SharedPreferences
      final Map<String, dynamic> data = json.decode(response.body);
      holidays = data.map((key, value) => MapEntry(key, value as String));

      // Save holidays to SharedPreferences for future use
      await prefs.setString('holidays_$year', json.encode(holidays));
    } else {
      // Handle API error
      throw Exception("Failed to load holidays for year $year");
    }
  }

  // Return the holiday name if it exists, or null if it doesn't
  return holidays[dateStr];
}

Future<String?> getUserRole() async {
  SharedPreferences userDetails = await SharedPreferences.getInstance();
  return userDetails.getString('role');
}

String getDayOfWeek(int dayNumber) {
  // List of days corresponding to weekdays (1 for Monday, 7 for Sunday)
  List<String> daysOfWeek = [
    "Monday",    // 1
    "Tuesday",   // 2
    "Wednesday", // 3
    "Thursday",  // 4
    "Friday",    // 5
    "Saturday",  // 6
    "Sunday"     // 7
  ];

  // Validate input: return an error message if out of range
  if (dayNumber < 1 || dayNumber > 7) {
    return "Invalid day number. Please enter a number between 1 and 7.";
  }

  // Return the corresponding day (adjust index by subtracting 1)
  return daysOfWeek[dayNumber - 1];
}

