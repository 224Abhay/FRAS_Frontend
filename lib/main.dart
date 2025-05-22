import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'services/functions.dart';
import 'screens/main_screen_admin.dart';
import 'screens/main_screen_student.dart';
import 'screens/main_screen_teacher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart' as api_service;

import 'screens/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  bool isLoggedIn = false;
  bool isLoading = true;
  String? role;
  String? refreshToken;

  @override
  void initState() {
    super.initState();
    debugPaintSizeEnabled = false; // Enables borders around all widgets
    initData();
  }

  Future<void> initData() async {
    // SharedPreferences prefs = await SharedPreferences.getInstance();
    // await prefs.clear();
    await api_service.init();
    await _checkLoginStatus();
  }

  Future<void> _loadRefreshToken() async {
    SharedPreferences credentials = await SharedPreferences.getInstance();
    refreshToken = credentials.getString('refresh_token');
  }

  Future<void> _checkLoginStatus() async {
    _loadRefreshToken();

    if (api_service.accessToken != null) {
      final response = await _validateAccessToken();
      if (response == 200) {
        setState(() {
          isLoggedIn = true;
          isLoading = false;
        });
      } else if (response == 401 && refreshToken != null) {
        await refreshAccessToken();
      } else {
        setState(() {
          isLoggedIn = false;
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoggedIn = false;
        isLoading = false;
      });
    }
  }

  Future<int> _validateAccessToken() async {
    final response = await api_service.postApiRequest("/auth/validate", null);
    return response.statusCode;
  }

  Future<void> refreshAccessToken() async {
    final response = await api_service
        .postApiRequest("/auth/refresh", {'refresh_token': refreshToken});

    if (response.statusCode == 200) {
      var responseData = jsonDecode(response.body);
      api_service.accessToken = responseData['access_token'];

      SharedPreferences credentials = await SharedPreferences.getInstance();
      await credentials.setString(
          'access_token', api_service.accessToken ?? "");

      role = await getUserRole();

      if (role != null) {
        setState(() {
          isLoggedIn = true;
          isLoading = false;
        });
        navigateBasedOnRole();
      }
    } else {
      setState(() {
        isLoggedIn = false;
        isLoading = false;
      });
    }
  }

  void navigateBasedOnRole() {
    if (role == 'admin') {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => const AdminMainScreen()));
    } else if (role == 'student') {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => const StudentMainScreen()));
    } else if (role == 'teacher') {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => const TeacherMainScreen()));
    } else {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    } else {
      return MaterialApp(
        theme: ThemeData(
          primaryColor: const Color(0xFF2970FE),
          scaffoldBackgroundColor:
              Colors.white, // Set the background color of the entire scaffold
          cardColor: Colors.white, // Set the background color of card widgets
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white, // AppBar background color
            elevation: 0, // Remove the shadow/elevation (optional)
            iconTheme: IconThemeData(
                color: Color(0xFF2970FE)), // Set icon color in AppBar
            actionsIconTheme: IconThemeData(
                color: Color(0xFF2970FE)), // Set action icon color in AppBar
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Colors.white, // Bottom navbar background color
            selectedItemColor: Color(0xFF2970FE), // Selected icon color
            unselectedItemColor:
                Colors.grey, // Unselected icon color (optional)
          ),
          dialogTheme: const DialogTheme(
            backgroundColor:
                Colors.white, // Set background color for all dialogs
          ),
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: Color(
                0xFF2970FE), // Default color for CircularProgressIndicator
          ),
        ),
        home: isLoggedIn
            ? FutureBuilder<String?>(
                future: getUserRole(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  } else if (snapshot.hasData) {
                    String? role = snapshot.data;

                    if (role == 'admin') {
                      return const AdminMainScreen();
                    } else if (role == 'student') {
                      return const StudentMainScreen();
                    } else if (role == 'teacher') {
                      return const TeacherMainScreen();
                    } else {
                      return const LoginScreen();
                    }
                  } else {
                    return const LoginScreen();
                  }
                },
              )
            : const LoginScreen(),
      );
    }
  }
}
