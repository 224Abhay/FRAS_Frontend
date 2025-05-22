import 'dart:convert';

import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../models/student.dart';
import '../models/subject.dart';
import '../services/functions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:camera/camera.dart';
import '../models/teacher.dart';
import '../models/timetable.dart';
import '../services/api_service.dart' as api_service;

Teacher? teacher;
List<TeacherSubject> teacherSubjects = [];
Map<String, Map<int, List<TTimetable>>> cachedTimetable = {};
Map<String, List<SubjectStats>> cachedSubjectStats = {};
Map<String, List<AttendanceStats>> cachedAttendanceStats = {};

DateTime _selectedDate = DateTime.now();
final ValueNotifier<DateTime> _currentWeekStartDateNotifier =
    ValueNotifier(DateTime.now());

String? selectedSession;
String? holidayName;

class TeacherMainScreen extends StatefulWidget {
  const TeacherMainScreen({super.key});

  @override
  TeacherMainScreenState createState() => TeacherMainScreenState();
}

class TeacherMainScreenState extends State<TeacherMainScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  final List<Widget> _screens = [
    const DashboardScreen(),
    const SubjectsScreen(),
    const UserProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Subjects',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'User',
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  bool isLoading = true;

  final List<String> months = List.generate(
      12,
      (index) =>
          DateFormat.MMMM().format(DateTime(0, index + 1)).substring(0, 3));

  @override
  void initState() {
    super.initState();
    initData();
  }

  Future<void> initData() async {
    _currentWeekStartDateNotifier.value = getStartOfWeek(_selectedDate);
    teacher = await Teacher.fromSP();
    await fetchClasses();
    await _onDateSelected(_selectedDate);

    await _fetchSchedule();
  }

  Future<void> fetchClasses() async {
    int? teacherId = teacher?.teacherId;
    if (teacherSubjects.isEmpty) {
      final response = await api_service
          .getApiRequest('/teacher/classes?teacher_id=$teacherId');
      if (response.statusCode == 200) {
        teacherSubjects = TeacherSubject.parseList(response.body);
        print(response.body);
      }
    }
  }

  Future<void> _fetchSchedule() async {
    DateTime date = _selectedDate;
    String semesterType = date.month <= 6 ? "S" : "A";
    List<Map<String, dynamic>> classSubject = [];

    for (var subject in teacherSubjects) {
      if (subject.semesterType == semesterType) {
        if (semesterType == "S") {
          if (date.year == subject.batchOf - subject.year) {
            classSubject.add({
              "class_id": subject.classId,
              "subject_code": subject.subjectCode
            });
          }
        } else {
          if (date.year == subject.batchOf - subject.year + 1) {
            classSubject.add({
              "class_id": subject.classId,
              "subject_code": subject.subjectCode
            });
          }
        }
      }
    }
    cachedTimetable[date.year.toString() + semesterType] ??= {};

    if (cachedTimetable[date.year.toString() + semesterType]!
        .containsKey(date.weekday)) {
      setState(() {
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = true;
      });
      List<TTimetable> schedule = [];

      final response = await api_service.postApiRequest('/teacher/schedule', {
        'class_subjects': classSubject,
        'day': date.weekday,
      });
      if (response.statusCode == 200) {
        schedule = TTimetable.parseList(response.body);
        cachedTimetable[date.year.toString() + semesterType]?[date.weekday] =
            schedule;
      }
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<List<Attendance>> getAttendanceStatus(
      List<TTimetable> schedule, DateTime date) async {
    List<dynamic> timetableIds =
        schedule.map((timetable) => timetable.timetableId).toList();

    final response = await api_service.postApiRequest(
        '/teacher/attendance_status',
        {'timetable_ids': timetableIds, 'date': date.toString()});

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => Attendance.fromJson(item)).toList();
    } else if (response.statusCode == 400) {
      throw Exception('Missing parameters');
    } else if (response.statusCode == 404) {
      return [];
    } else {
      throw Exception('Failed to fetch attendance');
    }
  }

  Widget _buildMonthSelector() {
    return ValueListenableBuilder<DateTime>(
      valueListenable:
          _currentWeekStartDateNotifier, // Listen to the changes in the notifier
      builder: (context, date, child) {
        // If the selected date is the same as the current week start date or the selected date is in the first week of the year
        if (_getWeekOfYear(date) == _getWeekOfYear(_selectedDate) ||
            _getWeekOfYear(_selectedDate) == 1) {
          date = _selectedDate;
        }
        int selectedYear = date.year;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  _showMonthPicker(context);
                },
                child: Text(
                  '${months[date.month - 1]} $selectedYear', // Display month and year
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMonthPicker(BuildContext context) {
    int selectedYear = _selectedDate.year;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows you to control the height of the modal
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              height: 500, // Set the fixed height for the modal content
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 15),
                  Container(
                    height: 5,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Select Month & Year',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_left, size: 32.0),
                        onPressed: () => setState(() => selectedYear--),
                      ),
                      Text(
                        '$selectedYear',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_right, size: 32.0),
                        onPressed: () => setState(() => selectedYear++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Container(
                    child: GridView.count(
                      shrinkWrap:
                          true, // Prevent scrolling by shrinking the grid to fit
                      physics:
                          NeverScrollableScrollPhysics(), // Disable scrolling
                      crossAxisCount: 3, // Number of columns in the grid
                      mainAxisSpacing: 15, // Space between rows
                      crossAxisSpacing: 15, // Space between columns
                      childAspectRatio: 2.2, // Aspect ratio of each grid item
                      children: List.generate(months.length, (index) {
                        return GestureDetector(
                          onTap: () {
                            _onMonthAndYearSelected(index + 1, selectedYear);
                            Navigator.pop(context);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xAA2970FE), Color(0xFF6A9AFE)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(4, 4),
                                ),
                              ],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                months[index],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _onMonthAndYearSelected(int month, int year) {
    setState(() {
      _selectedDate = DateTime(year, month, 1);
      _currentWeekStartDateNotifier.value = getStartOfWeek(_selectedDate);
      _fetchSchedule();
    });
  }

  Future<void> _onDateSelected(DateTime date) async {
    holidayName = await checkHoliday(date);
    if (holidayName != null) {
      setState(() {
        holidayName = holidayName;
        _selectedDate = date;
      });
    } else {
      setState(() {
        holidayName = null;
        _selectedDate = date;
      });
    }
    _fetchSchedule();
  }

  // Build the horizontal week calendar
  Widget _buildWeeklyCalendar() {
    List<DateTime> weekDates = getCurrentWeekDates();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 80,
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! < 0) {
            // Move to next week (add 7 days)
            _currentWeekStartDateNotifier.value = _currentWeekStartDateNotifier
                .value
                .add(const Duration(days: 7));
          } else if (details.primaryVelocity! > 0) {
            // Move to previous week (subtract 7 days)
            _currentWeekStartDateNotifier.value = _currentWeekStartDateNotifier
                .value
                .subtract(const Duration(days: 7));
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            double dateWidth = (constraints.maxWidth - 60) / 7;

            return ValueListenableBuilder<DateTime>(
              valueListenable: _currentWeekStartDateNotifier,
              builder: (context, currentWeekStartDate, child) {
                // Rebuild only when the week start date changes
                weekDates = getCurrentWeekDates();

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: weekDates.length,
                  itemBuilder: (context, index) {
                    DateTime currentDate = weekDates[index];
                    String dayOfWeek =
                        DateFormat.E().format(currentDate); // Short day name

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _onDateSelected(currentDate);
                        });
                      },
                      child: Container(
                        width: dateWidth,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          children: [
                            Text(
                              dayOfWeek,
                              style: GoogleFonts.poppins(
                                  fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            CircleAvatar(
                              backgroundColor:
                                  currentDate.day == _selectedDate.day &&
                                          currentDate.month ==
                                              _selectedDate.month &&
                                          currentDate.year == _selectedDate.year
                                      ? const Color(0xFF2970FE)
                                      : Colors.transparent,
                              child: Text(
                                '${currentDate.day}',
                                style: GoogleFonts.poppins(
                                    color:
                                        currentDate.day == _selectedDate.day &&
                                                currentDate.month ==
                                                    _selectedDate.month &&
                                                currentDate.year ==
                                                    _selectedDate.year
                                            ? Colors.white
                                            : Colors.black,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  // Get the week number of the year (ISO 8601)
  int _getWeekOfYear(DateTime date) {
    DateTime firstDayOfYear = DateTime(date.year, 1, 1);
    int daysDifference = date.difference(firstDayOfYear).inDays;
    return ((daysDifference + firstDayOfYear.weekday - 1) / 7).floor() + 1;
  }

  // Get the dates of the current week based on the current week start date
  List<DateTime> getCurrentWeekDates() {
    return List<DateTime>.generate(7, (index) {
      return _currentWeekStartDateNotifier.value.add(Duration(days: index));
    });
  }

  void _showAttendanceOptions(TTimetable timetable, int attendanceStatus) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Mark Attendance via CCTV'),
                onTap: () {},
              ),
              ListTile(
                title: const Text('Mark Attendance via Phone'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MarkAttendanceViaPhoto(),
                    ),
                  );
                  if (result == true) {
                    setState(() {
                      _fetchSchedule();
                    });
                  }
                },
              ),
              ListTile(
                title: const Text('Manual Attendance'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManualAttendanceScreen(
                          timetable: timetable,
                          attendanceStatus: attendanceStatus),
                    ),
                  );
                  if (result == true) {
                    setState(() {
                      _fetchSchedule();
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget timings(BuildContext context) {
    return const Column(
      children: [
        SizedBox(
          width: 60,
          height: 522,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: Text(
                  '08:00 am',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    height: 0.12,
                  ),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Future<Widget> _buildSchedule() async {
    DateTime date = _selectedDate;
    String semesterType = date.month <= 6 ? "S" : "A";
    List<TTimetable> schedule =
        cachedTimetable[date.year.toString() + semesterType]?[date.weekday] ??
            [];
    List<Attendance>? attendance;

    if (schedule.isNotEmpty) {
      attendance = await getAttendanceStatus(schedule, _selectedDate);
    } else {
      attendance = null;
    }

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (schedule.isEmpty) {
      return const Center(
        child: Text('No classes for the selected date'),
      );
    }

    return ListView.builder(
        itemCount: schedule.length,
        itemBuilder: (context, index) {
          final timetable = schedule[index];
          return _buildTimetableCard(timetable, attendance![index]);
        });
  }

  Widget _buildTimetableCard(TTimetable timetable, Attendance attendance) {
    List<String> endTime = timetable.endTime.split(":");

    Color boxColor;
    if (attendance.status == 1) {
      boxColor = const Color(0x70AAEFC6);
    } else if (DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            int.parse(endTime[0]),
            int.parse(endTime[1]),
            int.parse(endTime[2]))
        .isBefore(DateTime.now())) {
      boxColor = const Color(0x40FCA19B);
    } else {
      boxColor = const Color(0x40D3D3D3);
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            // Time Column
            SizedBox(
              width: 60,
              height: 70,
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  formatTime(timetable.startTime),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16), // Space between columns
            Expanded(
              child: InkWell(
                onTap: () =>
                    _showAttendanceOptions(timetable, attendance.status ?? 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: boxColor,
                    ),
                    child: Stack(
                      children: [
                        // Main content
                        Row(
                          children: [
                            // Left Rectangle
                            Container(
                              width: 5.2,
                              height: 75,
                              color: boxColor.withAlpha(255),
                            ),
                            SizedBox(
                              width: 290,
                              child: ListTile(
                                title: Text(
                                  timetable.subjectName,
                                  style: const TextStyle(
                                      height: 1.2,
                                      letterSpacing: 0.4,
                                      wordSpacing: 2),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(timetable.roomNumber
                                        .toString()), // Classroom
                                    Text(
                                        '${formatTime(timetable.startTime)} - ${formatTime(timetable.endTime)}'), // Time slot
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Padding(padding: EdgeInsets.only(left: 10)),
            Text(
              teacher != null
                  ? "${teacher!.teacherName} ${teacher!.teacherSurname}"
                  : "",
              style: const TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            CircleAvatar(
              backgroundColor: const Color(0xFF2970FE),
              child: Text(
                teacher != null
                    ? getInitials(teacher?.teacherName ?? "",
                        teacher?.teacherSurname ?? "")
                    : "",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.notifications), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          _buildMonthSelector(), // Month selector with dropdown
          _buildWeeklyCalendar(), // Horizontal calendar view
          const SizedBox(height: 16), // Replace Divider with Padding
          Expanded(
            child: holidayName != null
                ? Center(
                    child: Text(
                      'Holiday: $holidayName',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w500),
                      overflow: TextOverflow
                          .ellipsis, // Adds "..." if the text overflows
                    ),
                  )
                : FutureBuilder<Widget>(
                    future: _buildSchedule(),
                    builder:
                        (BuildContext context, AsyncSnapshot<Widget> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else if (snapshot.hasData) {
                        return snapshot
                            .data!; // Return the widget once it's ready
                      } else {
                        return const Text('No data available');
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ManualAttendanceScreen extends StatefulWidget {
  final TTimetable timetable;
  final int attendanceStatus;

  const ManualAttendanceScreen(
      {super.key, required this.timetable, required this.attendanceStatus});

  @override
  ManualAttendanceScreenState createState() => ManualAttendanceScreenState();
}

class ManualAttendanceScreenState extends State<ManualAttendanceScreen> {
  List<Student> students = [];
  Set<int> selectedStudentIds = {};
  Set<int> presentStudentIds = {};
  Set<int> absentStudentIds = {};

  @override
  void initState() {
    super.initState();
    fetchStudents();
  }

  Future<void> fetchStudents() async {
    final response = await api_service
        .getApiRequest('/students?batch_id=${widget.timetable.batchId}');
    if (response.statusCode == 200) {
      setState(() {
        students = Student.parseList(response.body);
      });
    }

    if (widget.attendanceStatus == 1) {
      final response = await api_service.getApiRequest(
          '/teacher/attendance?timetable_id=${widget.timetable.timetableId}&date=${formatDate(_selectedDate)}');
      if (response.statusCode == 200) {
        final List<dynamic> attendanceData = jsonDecode(response.body);
        setState(() {
          selectedStudentIds = attendanceData
              .where((record) => record['status'] == 1)
              .map<int>((record) => record['student_id'])
              .toSet();
        });
      }
    }
  }

  Future<void> submitAttendance() async {
    List<Map<String, dynamic>> attendanceRecords = [];

    if (widget.attendanceStatus == 0) {
      absentStudentIds.addAll(students
          .where((student) => !presentStudentIds.contains(student.studentId))
          .map((student) => student.studentId));
    }

    attendanceRecords.addAll(presentStudentIds.map((id) {
      return {
        'student_id': id,
        'timetable_id': widget.timetable.timetableId,
        'status': 1,
        'date': formatDate(_selectedDate),
        'room_number': widget.timetable.roomNumber,
      };
    }).toList());

    attendanceRecords.addAll(absentStudentIds.map((id) {
      return {
        'student_id': id,
        'timetable_id': widget.timetable.timetableId,
        'status': 0,
        'date': formatDate(_selectedDate),
        'room_number': widget.timetable.roomNumber,
      };
    }).toList());

    await api_service.postApiRequest(
        '/teacher/update_attendance', attendanceRecords);

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assign Students')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                int studentId = student.studentId;
                return ListTile(
                  leading: Checkbox(
                    value: selectedStudentIds.contains(student.studentId),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          selectedStudentIds.add(studentId);
                          if (absentStudentIds.contains(studentId)) {
                            absentStudentIds.remove(studentId);
                          } else {
                            presentStudentIds.add(studentId);
                          }
                        } else {
                          selectedStudentIds.remove(studentId);
                          if (presentStudentIds.contains(studentId)) {
                            presentStudentIds.remove(studentId);
                          } else {
                            absentStudentIds.add(studentId);
                          }
                        }
                      });
                    },
                  ),
                  title:
                      Text('${student.studentName} ${student.studentSurname}'),
                  subtitle: Text(student.studentId.toString()),
                  // trailing: CircleAvatar(
                  //   backgroundImage: NetworkImage(student.profileImageUrl), // Assuming URL is available
                  // ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: submitAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                      0xFF2970FE), // Match the blue color from your image
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Submit',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MarkAttendanceViaPhoto extends StatefulWidget {
  const MarkAttendanceViaPhoto({super.key});

  @override
  MarkAttendanceViaPhotoState createState() => MarkAttendanceViaPhotoState();
}

class MarkAttendanceViaPhotoState extends State<MarkAttendanceViaPhoto> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      throw Exception("Camera permission not granted");
    }
  }

  Future<void> _initializeCamera() async {
    await _checkPermissions();
    _cameras = await availableCameras();
    _cameraController = CameraController(
      _cameras![0],
      ResolutionPreset.high,
    );
    await _cameraController!.initialize();
    await _cameraController!.setFlashMode(FlashMode.off);
    setState(() {
      _isCameraInitialized = true;
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _captureAndUploadPhoto() async {
    if (!_cameraController!.value.isInitialized) return;

    try {
      final photo = await _cameraController!.takePicture();

      // Read the image as bytes
      final imageBytes = await photo.readAsBytes();

      // Encode the image as base64
      final base64Image = base64Encode(imageBytes);

      // Prepare the body for the API request
      final body = {
        'photo': base64Image,
        'filename': photo.name, // Add filename if needed
      };

      // Use the existing `postApiRequest` function
      final response =
          await api_service.postApiRequest("/teacher/mark_attendance", body);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance marked: ${jsonResponse["message"]}'),
          ),
        );
        setState(() {});
        Navigator.pop(context, true); // Navigate back to the dashboard
      } else {
        final errorResponse = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${errorResponse["message"]}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mark Attendance via Photo")),
      body: _isCameraInitialized
          ? Stack(
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3, // Set the aspect ratio to 4:3
                  child: CameraPreview(_cameraController!),
                ),
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: FloatingActionButton(
                        onPressed: _captureAndUploadPhoto,
                        backgroundColor: Colors.blue,
                        child:
                            const Icon(Icons.camera_alt, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  SubjectsScreenState createState() => SubjectsScreenState();
}

class SubjectsScreenState extends State<SubjectsScreen> {
  List<SubjectStats> subjectStats = [];
  List<AttendanceStats> attendanceStats = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    String semesterType = now.month <= 6 ? "S" : "A";
    List<TeacherSubject> currentYearClasses = teacherSubjects.where((subject) {
      int year = subject.batchOf - subject.courseDuration + subject.year;
      if (semesterType == "A") {
        year += 1;
      }
      return year == now.year && subject.semesterType == semesterType;
    }).toList();
    fetchSubjectsStats(currentYearClasses, forceRefresh: true);
  }

  Future<void> fetchSubjectsStats(List<TeacherSubject>? classes,
      {bool forceRefresh = false}) async {
    setState(() {
      isLoading = true;
    });

    if (forceRefresh) {
      final response = await api_service
          .getApiRequest('/teacher/session_stats?classes=$classes');

      if (response.statusCode == 200) {
        final List<SubjectStats> fetchedSubjects =
            SubjectStats.parseList(response.body);
        cachedSubjectStats[selectedSession ?? ""] = fetchedSubjects;
      }
    }
    setState(() {
      subjectStats = cachedSubjectStats[selectedSession] ?? [];
      isLoading = false;
    });
  }

  Future<void> fetchAttendanceDetails(int teacherId, String subjectCode,
      {bool forceRefresh = false}) async {
    if (!cachedAttendanceStats.containsKey(subjectCode) || forceRefresh) {
      final response = await api_service.getApiRequest(
          '/teacher/attendance_stats?teacher_id=$teacherId&subject_code=$subjectCode');

      if (response.statusCode == 200) {
        final List<AttendanceStats> fetchedAttendanceDetails =
            AttendanceStats.parseList(response.body);

        cachedAttendanceStats[subjectCode] = fetchedAttendanceDetails;
      }
    }
    attendanceStats = cachedAttendanceStats[subjectCode] ?? [];
  }

  void showSubjectDetails(BuildContext context, SubjectStats subject) async {
    await fetchAttendanceDetails(teacher?.teacherId ?? 0, subject.subjectCode);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.only(left: 20.0, top: 50.0, right: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.75,
                    child: Text(
                      subject.subjectName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              // Table headers with percentage-based width
              Table(
                children: const [
                  TableRow(
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                            left: 15.0), // Increased padding above status
                        child: Text(
                          "Date",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18.0),
                        ),
                      ),
                      Center(
                        // Center the content inside the Status column
                        child: Text(
                          "Status",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18.0),
                        ),
                      ),
                      Center(
                        // Center the content inside the Action column
                        child: Text(
                          "Action",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18.0),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              attendanceStats.isNotEmpty
                  ? ListView.builder(
                      shrinkWrap: true,
                      itemCount: attendanceStats.length,
                      itemBuilder: (context, index) {
                        final attendance = attendanceStats[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Table(
                            children: [
                              TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left:
                                            15), // Increased padding above status
                                    child: Text(
                                      "${attendance.date}\n${attendance.startTime.substring(0, 5)} to ${attendance.endTime.substring(0, 5)}",
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top:
                                            8.0), // Increased padding above status
                                    child: Center(
                                      // Center the content inside the Status column
                                      child: Text(
                                        attendance.status == 1
                                            ? "Present"
                                            : "Absent",
                                        style: TextStyle(
                                          color: attendance.status == 1
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: attendance.status == 1
                                        ? null
                                        : ElevatedButton(
                                            onPressed: () {},
                                            style: ElevatedButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              backgroundColor:
                                                  Colors.blueAccent,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                              textStyle:
                                                  const TextStyle(fontSize: 14),
                                            ),
                                            child: const Text("Request"),
                                          ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                              padding: EdgeInsets.only(
                                  top:
                                      MediaQuery.of(context).size.width * 0.5)),
                          const Text(
                            "No attendance records found",
                            style: TextStyle(
                              fontSize: 22, // Increase font size
                              fontWeight: FontWeight.bold,
                              color: Colors
                                  .grey, // Optional: make the color more neutral
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, List<TeacherSubject>> sessions = {};

    for (TeacherSubject semester in teacherSubjects) {
      int held = semester.batchOf - semester.courseDuration + semester.year - 1;
      if (semester.semesterType == "S") {
        held = semester.batchOf - semester.courseDuration + semester.year;
      }
      String key = "$held${semester.semesterType}";
      if (!sessions.containsKey(key)) {
        sessions[key] = [];
      }
      sessions[key]!.add(semester);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subjects'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Dropdown selection for classes
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Color(0xFFEAECF0), width: 1),
              ),
              child: DropdownButtonFormField<String>(
                value: selectedSession,
                items: sessions.keys.map((key) {
                  final year = key.substring(0, 4);
                  final semesterType =
                      key.substring(4) == 'A' ? 'Autumn' : 'Spring';
                  return DropdownMenuItem(
                    value: key,
                    child: Text('$year $semesterType'),
                  );
                }).toList(),
                onChanged: (selectedKey) {
                  if (selectedKey != null) {
                    setState(() {
                      selectedSession = selectedKey;
                    });
                    print(sessions[selectedSession]);
                    fetchSubjectsStats(sessions[selectedSession]!);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Select Semester',
                  border: InputBorder.none,
                ),
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: subjectStats.length,
                      itemBuilder: (context, index) {
                        final subject = subjectStats[index];
                        return GestureDetector(
                          onTap: () => showSubjectDetails(context, subject),
                          child: SubjectCard(subject: subject),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class SubjectCard extends StatelessWidget {
  final SubjectStats subject;

  const SubjectCard({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    double attendancePercentage =
        (subject.attended ?? 0) > 0 && (subject.total ?? 0) > 0
            ? (subject.attended! / subject.total!) * 100
            : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.subjectName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(subject.subjectCode),
                Text('${subject.attended}/${subject.total} Attended'),
              ],
            ),
            CircularPercentIndicator(
              radius: 40.0,
              lineWidth: 5.0,
              percent: attendancePercentage / 100,
              center: Text('${attendancePercentage.toInt()}%'),
              progressColor: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }
}

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  UserProfileScreenState createState() => UserProfileScreenState();
}

class UserProfileScreenState extends State<UserProfileScreen> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> logout() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.clear();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'User Profile',
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: IconThemeData(color: Colors.black), // AppBar icon color
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Profile Image Section
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFF2970FE),
                child: Text(
                  getInitials(teacher?.teacherName ?? '',
                      teacher?.teacherSurname ?? ''),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // User Info Section
            Card(
              color: Color(0xFEFAF9F6),
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserInfoRow('Name',
                        '${teacher?.teacherName} ${teacher?.teacherSurname}'),
                    _buildUserInfoRow('Email', '${teacher?.teacherEmail}'),
                  ],
                ),
              ),
            ),

            const Spacer(), // Push the log-out button to the bottom

            // Log Out Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2970FE), // Button color
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 5, // Add shadow to the button
                ),
                child: const Text(
                  'Log Out',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// Helper widget for displaying user info row
  Widget _buildUserInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
