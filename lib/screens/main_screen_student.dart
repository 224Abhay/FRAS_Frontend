import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:identify_fras/screens/login_screen.dart';
import 'package:identify_fras/utils/FaceCaptureScreen.dart';
import '../../models/subject.dart';
import '../../services/functions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/Branch.dart';
import '../../models/student.dart';
import '../../models/timetable.dart';
import '../../services/api_service.dart' as api_service;

Student? student;
Batch? batch;
Branch? branch;
List<Class> classes = [];
Map<int, Map<int, List<STimetable>>> cachedTimetable = {};
Map<int, List<SubjectStats>> cachedSubjectStats = {};
Map<String, List<AttendanceStats>> cachedAttendanceStats = {};
Map<int, Map<String, String>> cachedHolidays = {};

DateTime _selectedDate = DateTime.now();
final ValueNotifier<DateTime> _currentWeekStartDateNotifier = ValueNotifier(DateTime.now());
int? selectedClassId;
Class? selectedClass;
String? holidayName;

class StudentMainScreen extends StatefulWidget {
  const StudentMainScreen({super.key});

  @override
  StudentMainScreenState createState() => StudentMainScreenState();
}

class StudentMainScreenState extends State<StudentMainScreen> {
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

  final List<String> months = List.generate(12, (index) => DateFormat.MMMM().format(DateTime(0, index + 1)).substring(0, 3));

  @override
  void initState() {
    super.initState();
    initData();
  }

  Future<void> initData() async {
    _currentWeekStartDateNotifier.value = getStartOfWeek(_selectedDate);

    student = await Student.fromSP();
    batch = await Batch.fromSP();
    branch = await Branch.fromSP();

    await fetchClasses();
    _onDateSelected(_selectedDate);
  }

  Future<void> fetchClasses() async {
    int? batchId = batch?.batchId;
    if (classes.isEmpty) {
      final response = await api_service.getApiRequest('/student/classes?batch_id=$batchId');
      if (response.statusCode == 200) {
        classes = Class.parseList(response.body);
      }
    }
  }

  Future<void> _fetchSchedule() async {
    final int batchOf = batch!.batchOf;
    final int courseDuration = branch!.courseDuration;

    String semesterType = 'S';
    int classYear = courseDuration - batchOf + _selectedDate.year;

    if (_selectedDate.month > 6) {
      semesterType = 'A';
      classYear++;
    }

    if (classYear > courseDuration) {
      return;
    }

    int classId = Class.getClassId(classes, classYear, semesterType);
    selectedClassId = classId;
    cachedTimetable[classId] ??= {};

    if (cachedTimetable[classId]!.containsKey(_selectedDate.weekday)) {
      setState(() {
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = true;
      });

      print(classId);

      final response = await api_service.postApiRequest('/student/schedule', {
        'class_id': classId,
        'day': getDayOfWeek(_selectedDate.weekday),
      });
      if (response.statusCode == 200) {
        List<STimetable> schedule = STimetable.parseList(response.body);
        cachedTimetable[classId]?[_selectedDate.weekday] = schedule;
      }
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<List<Attendance>> fetchAttendance(List<STimetable> schedule, DateTime date) async {
    List<dynamic> timetableIds = schedule.map((timetable) => timetable.timetableId).toList();

    final response = await api_service.postApiRequest('/student/attendance', {'timetable_ids': timetableIds, 'date': date.toString()});

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      // Convert the response data into a list of Attendance objects
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
      valueListenable: _currentWeekStartDateNotifier,
      builder: (context, date, child) {
        if (_getWeekOfYear(date) == _getWeekOfYear(_selectedDate) || _getWeekOfYear(_selectedDate) == 1) {
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
                      shrinkWrap: true, // Prevent scrolling by shrinking the grid to fit
                      physics: NeverScrollableScrollPhysics(), // Disable scrolling
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

  Widget _buildWeeklyCalendar() {
    List<DateTime> weekDates = getCurrentWeekDates();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 80,
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! < 0) {
            _currentWeekStartDateNotifier.value = _currentWeekStartDateNotifier.value.add(const Duration(days: 7));
          } else if (details.primaryVelocity! > 0) {
            _currentWeekStartDateNotifier.value = _currentWeekStartDateNotifier.value.subtract(const Duration(days: 7));
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            double dateWidth = (constraints.maxWidth - 60) / 7;

            return ValueListenableBuilder<DateTime>(
              valueListenable: _currentWeekStartDateNotifier,
              builder: (context, currentWeekStartDate, child) {
                weekDates = getCurrentWeekDates();

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: weekDates.length,
                  itemBuilder: (context, index) {
                    DateTime currentDate = weekDates[index];
                    String dayOfWeek = DateFormat.E().format(currentDate); // Short day name

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
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            CircleAvatar(
                              backgroundColor: currentDate.day == _selectedDate.day && currentDate.month == _selectedDate.month && currentDate.year == _selectedDate.year ? const Color(0xFF2970FE) : Colors.transparent,
                              child: Text(
                                '${currentDate.day}',
                                style: GoogleFonts.poppins(color: currentDate.day == _selectedDate.day && currentDate.month == _selectedDate.month && currentDate.year == _selectedDate.year ? Colors.white : Colors.black, fontWeight: FontWeight.w500),
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

  int _getWeekOfYear(DateTime date) {
    DateTime firstDayOfYear = DateTime(date.year, 1, 1);
    int daysDifference = date.difference(firstDayOfYear).inDays;
    return ((daysDifference + firstDayOfYear.weekday - 1) / 7).floor() + 1;
  }

  List<DateTime> getCurrentWeekDates({DateTime? startDate}) {
    if (startDate != null) {
      return List<DateTime>.generate(7, (index) {
        return startDate.add(Duration(days: index));
      });
    }
    return List<DateTime>.generate(7, (index) {
      return _currentWeekStartDateNotifier.value.add(Duration(days: index));
    });
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
    List<STimetable> schedule = cachedTimetable[selectedClassId]?[_selectedDate.weekday] ?? [];

    List<Attendance>? attendance;

    if (schedule.isNotEmpty) {
      attendance = await fetchAttendance(schedule, _selectedDate);
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
        child: Text(
          'No classes for the selected date',
          style: TextStyle(fontSize: 16.0),
        ),
      );
    }

    return ListView.builder(
        itemCount: schedule.length,
        itemBuilder: (context, index) {
          final timetable = schedule[index];

          Color boxColor;
          if (attendance?[index].status == 1) {
            boxColor = const Color(0x70AAEFC6);
          } else if (attendance?[index].status == 0) {
            boxColor = const Color(0x40FCA19B);
          } else {
            boxColor = const Color(0x40D3D3D3);
          }

          return GestureDetector(
            onTap: () => _showSubjectDetails(context, timetable),
            child: _buildTimetableCard(timetable, boxColor),
          );
        });
  }

  void _showSubjectDetails(BuildContext context, STimetable timetable) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            timetable.subjectName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailTile(Icons.code, 'Subject Code', timetable.subjectCode),
                _buildDetailTile(Icons.person, 'Teacher', '${timetable.teacherName} ${timetable.teacherSurname}'),
                _buildDetailTile(Icons.room, 'Room Number', timetable.roomNumber),
                _buildDetailTile(Icons.calendar_today, 'Day', timetable.day),
                _buildDetailTile(Icons.access_time, 'Timings', "${timetable.startTime} to ${timetable.endTime}"),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(value, style: TextStyle(fontSize: 16)),
      contentPadding: EdgeInsets.symmetric(vertical: 4.0),
    );
  }

  Widget _buildTimetableCard(STimetable timetable, Color? boxColor) {
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

            // Subject Details Container with dynamic color
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  decoration: BoxDecoration(
                    color: boxColor, // Use the dynamic color here
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
                            color: boxColor?.withAlpha(255),
                          ),
                          SizedBox(
                            width: 290,
                            child: ListTile(
                              title: Text(
                                timetable.subjectName,
                                style: const TextStyle(height: 1.2, letterSpacing: 0.4, wordSpacing: 2),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(timetable.roomNumber.toString()), // Classroom
                                  Text('${formatTime(timetable.startTime)} - ${formatTime(timetable.endTime)}'), // Time slot
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Circular icon at top right
                      Positioned(
                        right: 8,
                        top: 8,
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.blue,
                          child: Text(
                            timetable.teacherName[0] + timetable.teacherSurname[0],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Padding(padding: EdgeInsets.only(left: 10)),
            Text(
              student?.studentId.toString() ?? "",
              style: const TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            IconButton(icon: const Icon(Icons.notifications), onPressed: () {}),
            const Padding(padding: EdgeInsets.only(right: 10.0)),
            CircleAvatar(
              backgroundColor: const Color(0xFF2970FE),
              child: Text(
                student != null ? getInitials(student?.studentName ?? "", student?.studentSurname ?? "") : "",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
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
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis, // Adds "..." if the text overflows
                    ),
                  )
                : FutureBuilder<Widget>(
                    future: _buildSchedule(),
                    builder: (BuildContext context, AsyncSnapshot<Widget> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else if (snapshot.hasData) {
                        return snapshot.data!; // Return the widget once it's ready
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
    selectedClass ??= classes[0];
    fetchSubjectsStats(selectedClass?.classId ?? 0);
  }

  Future<void> fetchSubjectsStats(int classId, {bool forceRefresh = false}) async {
    setState(() {
      isLoading = true;
    });

    if (!cachedSubjectStats.containsKey(classId) || forceRefresh) {
      final response = await api_service.getApiRequest('/student/subject_stats?class_id=$classId');

      if (response.statusCode == 200) {
        final List<SubjectStats> fetchedSubjects = SubjectStats.parseList(response.body);
        cachedSubjectStats[classId] = fetchedSubjects;
      }
    }
    setState(() {
      subjectStats = cachedSubjectStats[classId] ?? [];
      isLoading = false;
    });
  }

  Future<void> fetchAttendanceDetails(String subjectCode, {bool forceRefresh = false}) async {
    if (!cachedAttendanceStats.containsKey(subjectCode) || forceRefresh) {
      final response = await api_service.getApiRequest('/student/attendance_stats?subject_code=$subjectCode');

      if (response.statusCode == 200) {
        final List<AttendanceStats> fetchedAttendanceDetails = AttendanceStats.parseList(response.body);

        cachedAttendanceStats[subjectCode] = fetchedAttendanceDetails;
      }
    }
    attendanceStats = cachedAttendanceStats[subjectCode] ?? [];
  }

  void showSubjectDetails(BuildContext context, SubjectStats subject) async {
    // Show loading dialog before fetching data
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    // Fetch attendance details
    await fetchAttendanceDetails(subject.subjectCode);

    if (context.mounted) Navigator.pop(context);

    if (!context.mounted) return;

    // Show the bottom sheet
    showModalBottomSheet(
      backgroundColor: const Color(0xFFF2F5FA),
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
                      style: const TextStyle(fontSize: 18),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Table(
                children: const [
                  TableRow(
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 15.0),
                        child: Text(
                          "Date",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
                        ),
                      ),
                      Center(
                        child: Text(
                          "Status",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
                        ),
                      ),
                      Center(
                        child: Text(
                          "Action",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
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
                                    padding: const EdgeInsets.only(left: 15),
                                    child: Text(
                                      "${attendance.date}\n${attendance.startTime.substring(0, 5)} to ${attendance.endTime.substring(0, 5)}",
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Center(
                                      child: Text(
                                        attendance.status == 1 ? "Present" : "Absent",
                                        style: TextStyle(
                                          color: attendance.status == 1 ? Colors.green : Colors.red,
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
                                              backgroundColor: Colors.blueAccent,
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              textStyle: const TextStyle(fontSize: 14),
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
                          Padding(padding: EdgeInsets.only(top: MediaQuery.of(context).size.width * 0.5)),
                          const Text(
                            "No attendance records found",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Center(child: Text('Subjects')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Dropdown selection for classes
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: const Color(0x90F2F5FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEAECF0), width: 1),
              ),
              child: DropdownButtonFormField<Class>(
                value: classes.isNotEmpty ? classes.first : null,
                items: classes.map((cls) {
                  final sem = cls.semesterType == 'A' ? (cls.year * 2 - 1) : (cls.year * 2);
                  return DropdownMenuItem(
                    value: cls,
                    child: Text("Semester $sem (${cls.semesterType == 'A' ? 'July to Dec' : 'Jan to June'})"),
                  );
                }).toList(),
                onChanged: (selectedClass) {
                  if (selectedClass != null) {
                    setState(() {
                      selectedClass = selectedClass;
                    });
                    fetchSubjectsStats(selectedClass?.classId ?? 0);
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Select Semester',
                  border: InputBorder.none,
                ),
                dropdownColor: Colors.white,
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
    double attendancePercentage = (subject.attended ?? 0) > 0 && (subject.total ?? 0) > 0 ? (subject.attended! / subject.total!) * 100 : 0.0;

    return Card(
      color: const Color(0xFFF2F5FA),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 260, // Set your desired width here
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.subjectName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(subject.subjectCode),
                  Text('${subject.attended}/${subject.total} Attended'),
                ],
              ),
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
                  getInitials(student?.studentName ?? '', student?.studentSurname ?? ''),
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
                    _buildUserInfoRow('Name', '${student?.studentName} ${student?.studentSurname}'),
                    _buildUserInfoRow('Email', '${student?.studentEmail}'),
                    _buildUserInfoRow('Branch', '${branch?.branchName}'),
                    _buildUserInfoRow('Year', '${classes[0].year}'),
                    _buildUserInfoRow('Semester', '${classes[0].semesterType == 'A' ? (classes[0].year * 2 - 1) : (classes[0].year * 2)}'),
                  ],
                ),
              ),
            ),

            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => FaceCaptureScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 5,
                ),
                child: const Text(
                  'Change Face Data',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
