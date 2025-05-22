import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';
import '../models/Branch.dart';
import '../models/admin.dart';
import '../models/student.dart';
import '../models/subject.dart';
import '../models/teacher.dart';
import '../models/timetable.dart';
import '../services/api_service.dart' as api_service;
import '../services/functions.dart';

Admin? admin;

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  AdminMainScreenState createState() => AdminMainScreenState();
}

class AdminMainScreenState extends State<AdminMainScreen> {
  List<Branch> branches = [];
  List<Subject> subjects = [];
  List<Teacher> teachers = [];

  Map<int, List<Batch>> cachedBatches = {};
  Map<int, List<Class>> cachedBatchClasses = {};
  Map<int, List<Student>> cachedBatchStudents = {};
  Map<int, List<ClassSubject>> cachedClassSubjects = {};
  Map<int, List<Timetable>> cachedClassTimetable = {};

  int _selectedIndex = 0;
  int? selectedBranchId;
  int? selectedBatchId;
  int? selectedClassId;
  bool showingStudents = true;

  int? maxYears;
  final List<String> semesterTypes = [
    'Spring (Jan to June)',
    'Autumn (July to Dec)'
  ];

  @override
  void initState() {
    super.initState();
    initData();
  }

  Future<void> initData() async {
    await fetchBranches();
    await fetchSubjects();
    admin = await Admin.fromSP();
    fetchTeachers();
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

  Future<void> fetchBranches({bool forceRefresh = false}) async {
    if (branches.isEmpty || forceRefresh) {
      final response = await api_service.getApiRequest('/admin/branches');
      if (response.statusCode == 200) {
        final List<Branch> fetchedBranches = Branch.parseList(response.body);
        if (mounted) {
          setState(() {
            branches = fetchedBranches;
          });
        }
      }
    }
  }

  Future<void> fetchSubjects({bool forceRefresh = false}) async {
    if (subjects.isEmpty || forceRefresh) {
      final response = await api_service.getApiRequest('/admin/subjects');
      if (response.statusCode == 200) {
        final List<Subject> fetchedSubjects = Subject.parseList(response.body);
        if (mounted) {
          setState(() {
            subjects = fetchedSubjects;
          });
        }
      }
    }
  }

  Future<void> fetchTeachers({bool forceRefresh = false}) async {
    if (teachers.isEmpty || forceRefresh) {
      final response = await api_service.getApiRequest('/admin/teachers');
      if (response.statusCode == 200) {
        final List<Teacher> fetchedTeachers = Teacher.parseList(response.body);
        if (mounted) {
          setState(() {
            teachers = fetchedTeachers;
          });
        }
      }
    }
  }

  Future<void> fetchBatchesOfBranch(int branchId, int courseDuration,
      {bool forceRefresh = false}) async {
    if (!cachedBatches.containsKey(branchId) || forceRefresh) {
      final response =
          await api_service.getApiRequest('/admin/batches?branch_id=$branchId');
      if (response.statusCode == 200) {
        final List<Batch> fetchedBatches = Batch.parseList(response.body);
        cachedBatches[branchId] = fetchedBatches;
      }
    }
    if (mounted) {
      setState(() {
        selectedBranchId = branchId;
        maxYears = courseDuration;
      });
    }
  }

  Future<void> fetchStudentsOfBatch(int batchId,
      {bool forceRefresh = false}) async {
    if (!cachedBatchStudents.containsKey(batchId) || forceRefresh) {
      final response =
          await api_service.getApiRequest('/students?batch_id=$batchId');
      if (response.statusCode == 200) {
        final List<Student> fetchedStudents = Student.parseList(response.body);
        cachedBatchStudents[batchId] = fetchedStudents;
      }
    }
    if (mounted) {
      setState(() {
        selectedBatchId = batchId;
      });
    }
  }

  Future<void> fetchClassesOfBatch(int batchId,
      {bool forceRefresh = false}) async {
    if (!cachedBatchClasses.containsKey(batchId) || forceRefresh) {
      final response =
          await api_service.getApiRequest('/admin/classes?batch_id=$batchId');
      if (response.statusCode == 200) {
        final List<Class> fetchedClasses = Class.parseList(response.body);
        cachedBatchClasses[batchId] = fetchedClasses;
        if (fetchedClasses.isNotEmpty) {
          await fetchSubjectsOfClass(fetchedClasses[0].classId);
          fetchTimetableOfClass(fetchedClasses[0].classId);
        }
      }
    }
    setState(() {
      selectedBatchId = batchId;
    });
  }

  Future<void> fetchSubjectsOfClass(int classId,
      {bool forceRefresh = false}) async {
    if (!cachedClassSubjects.containsKey(classId) || forceRefresh) {
      final response =
          await api_service.getApiRequest('/admin/subjects?class_id=$classId');
      if (response.statusCode == 200) {
        final List<ClassSubject> fetchedSubjects =
            ClassSubject.parseList(response.body);
        cachedClassSubjects[classId] = fetchedSubjects;
      }
    }
    setState(() {});
  }

  Future<void> fetchTimetableOfClass(int classId,
      {bool forceRefresh = false}) async {
    if (!cachedClassTimetable.containsKey(classId) || forceRefresh) {
      final response =
          await api_service.getApiRequest('/admin/timetable?class_id=$classId');
      if (response.statusCode == 200) {
        final List<Timetable> fetchedTimetable =
            Timetable.parseList(response.body);
        cachedClassTimetable[classId] = fetchedTimetable;
      }
      setState(() {
        cachedClassTimetable[classId];
      });
    }
  }

  Widget _buildListTile(String heading,
      {List<String>? subHeadings, VoidCallback? onTap}) {
    return ListTile(
      title: Text(heading),
      subtitle: subHeadings != null && subHeadings.isNotEmpty
          ? Text(subHeadings.join('\n'))
          : null,
      onTap: onTap,
    );
  }

  Widget _buildCardTile(
    String heading, {
    List<String>? subHeadings,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2.0, // Elevation for the card shadow
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Heading
              Text(
                heading,
                style: const TextStyle(
                  fontSize: 16.0,
                  color: Colors.blueAccent, // Use a color that fits your design
                ),
              ),
              // SubHeadings (if available)
              if (subHeadings != null && subHeadings.isNotEmpty)
                Text(
                  subHeadings.join('\n'),
                  style: TextStyle(color: Colors.grey[600]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBranchesList() {
    return ListView.builder(
      itemCount: branches.length,
      itemBuilder: (context, index) {
        final branch = branches[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0), // Add padding
          child: _buildCardTile(
            branch.branchName,
            subHeadings: ['Course Duration: ${branch.courseDuration}'],
            onTap: () =>
                fetchBatchesOfBranch(branch.branchId, branch.courseDuration),
          ),
        );
      },
    );
  }

  Widget _buildSubjectsList() {
    return ListView.builder(
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        final subject = subjects[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0), // Add padding
          child: _buildCardTile(
            subject.subjectName,
            subHeadings: ['Subject Code: ${subject.subjectCode}'],
          ),
        );
      },
    );
  }

  Widget _buildTeachersList() {
    return ListView.builder(
      itemCount: teachers.length,
      itemBuilder: (context, index) {
        final teacher = teachers[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0), // Add padding
          child: _buildCardTile(
            '${teacher.teacherName} ${teacher.teacherSurname}',
            subHeadings: ['Email: ${teacher.teacherEmail}'],
          ),
        );
      },
    );
  }

  Widget _buildBatchesList() {
    final List<Batch> batches = cachedBatches[selectedBranchId] ?? [];
    showingStudents = true;

    final Map<int, List<Batch>> batchesByYear = {};
    for (var batch in batches) {
      batchesByYear.putIfAbsent(batch.batchOf, () => []).add(batch);
    }

    return ListView(
      children: batchesByYear.entries.map((entry) {
        final year = entry.key;
        final yearBatches = entry.value;

        return ExpansionTile(
          title: Text(
            'Batch of $year',
            style: const TextStyle(
              fontSize: 16.0,
              color: Colors.blueAccent, // Use a color that fits your design
            ),
          ),
          children: yearBatches.map((batchDetails) {
            return _buildListTile('Div: ${batchDetails.batch}',
                onTap: () => fetchStudentsOfBatch(batchDetails.batchId));
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildStudentsList() {
    List<Student> students = cachedBatchStudents[selectedBatchId] ?? [];

    return ListView.builder(
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0), // Add padding
          child: _buildCardTile(
            student.studentId.toString(),
            subHeadings: [
              'Name: ${student.studentName} ${student.studentSurname}',
              'Email: ${student.studentEmail}'
            ],
          ),
        );
      },
    );
  }

  Widget _buildClassesList() {
    final List<Class> classes = cachedBatchClasses[selectedBatchId] ?? [];

    return ListView.builder(
      itemCount: classes.length,
      itemBuilder: (context, index) {
        final classDetails = classes[index];
        final int year = classDetails.year;
        final int sem =
            classDetails.semesterType == 'A' ? (year * 2 - 1) : (year * 2);
        final int classId = classDetails.classId;
        final classSubjects = cachedClassSubjects[classId] ?? [];

        return ExpansionTile(
          title: Text('${getSuffix(year)} Year, ${getSuffix(sem)} Sem'),
          onExpansionChanged: (expanded) async {
            if (classSubjects.isEmpty) {
              await fetchSubjectsOfClass(classId);
              await fetchTimetableOfClass(classId);
            }
          },
          children: [
            ...classSubjects.map((subject) {
              final teacher =
                  Teacher.getTeacherName(subject.teacherId, teachers);
              final subjectName =
                  Subject.getSubjectName(subject.subjectCode, subjects);

              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0), // Horizontal padding
                child: SizedBox(
                  width:
                      double.infinity, // Ensures the card takes up full width
                  child: _buildCardTile(
                    subjectName,
                    subHeadings: ['Teacher: $teacher'],
                    onTap: () => showTimetableDialog(
                        context, classId, subjectName, subject.subjectCode),
                  ),
                ),
              );
            }),
            Padding(
              padding:
                  const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
              child: Card(
                elevation: 2.0, // Elevation for the card shadow
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0)),
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: SizedBox(
                    width: double
                        .infinity, // Ensures the card expands to full width
                    child: ListTile(
                      title: const Text('Assign New Subject'),
                      leading: const Icon(Icons.add),
                      onTap: () => _showAssignSubjectsDialog(classId),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

Widget buildNewTimetableEntryForm(
    BuildContext context, int classId, String subjectCode) {
  String? selectedDay;
  final TextEditingController roomNumberController = TextEditingController();
  int startHour = 8;
  int endHour = 19;

  // Function to update selected time in 24-hour format
  String formatTime(int hour) {
    String suffix = hour >= 12 ? 'PM' : 'AM';
    int hour12 = hour > 12
        ? hour - 12
        : hour == 0
            ? 12
            : hour;
    return '$hour12:00 $suffix';
  }

  return StatefulBuilder(
    builder: (context, setState) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Selection
          const Text("Select Day:", style: TextStyle(fontSize: 14.0)),
          const SizedBox(height: 8.0),
          Wrap(
            spacing: 8.0,
            children: [
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
              'Saturday',
            ].map((day) {
              bool isSelected = selectedDay == day;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedDay = day;
                  });
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? Colors.blue : Colors.grey[200],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    day[0], // Show first letter
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontSize: 14.0,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16.0),

          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 8.0), // Add padding to left and right
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween, // Adjust spacing
              children: [
                // Start Hour Picker
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Start Time:", style: TextStyle(fontSize: 14.0)),
                    DropdownButton<int>(
                      value: startHour,
                      onChanged: (newValue) {
                        setState(() {
                          startHour = newValue!;
                        });
                      },
                      items: List.generate(12, (index) {
                        int hour = 8 + index; // hours from 8 AM to 7 PM
                        return DropdownMenuItem<int>(
                          value: hour,
                          child: Text(formatTime(hour)),
                        );
                      }),
                    ),
                  ],
                ),

                // End Hour Picker
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("End Time:", style: TextStyle(fontSize: 14.0)),
                    DropdownButton<int>(
                      value: endHour,
                      onChanged: (newValue) {
                        setState(() {
                          endHour = newValue!;
                        });
                      },
                      items: List.generate(12, (index) {
                        int hour = 8 + index; // hours from 8 AM to 7 PM
                        return DropdownMenuItem<int>(
                          value: hour,
                          child: Text(formatTime(hour)),
                        );
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8.0),

          // Room Number
          TextField(
            controller: roomNumberController,
            decoration: const InputDecoration(labelText: 'Room Number'),
          ),
          const SizedBox(height: 16.0),

          // Add Timetable Entry Button (shifted to the right)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,  // Align to the right
            children: [
              TextButton(
                onPressed: () {
                  _addTimetableEntry(
                    classId,
                    subjectCode,
                    formatTimeToMySQL(TimeOfDay(hour: startHour, minute: 0)),
                    formatTimeToMySQL(TimeOfDay(hour: endHour, minute: 0)),
                    roomNumberController.text,
                    selectedDay!,
                  );
                },
                child: const Text('Add Timetable Entry'),
              ),
            ],
          ),
        ],
      );
    },
  );
}


  Widget _buildProfileScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Name: ${admin!.adminName} ${admin!.adminSurname}',
              style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text('Email: ${admin!.adminEmail}',
              style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        leading: _getLeadingIcon(),
        actions: _getAppBarActions(),
      ),
      body: _getBody(),
      floatingActionButton: _getFloatingActionButton(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  String _getAppBarTitle() {
    if (selectedBatchId != null) {
      return showingStudents ? 'Students' : 'Classes';
    }
    if (selectedBranchId != null) {
      return 'Batches';
    }
    switch (_selectedIndex) {
      case 0:
        return 'Branches';
      case 1:
        return 'Subjects';
      case 2:
        return 'Teachers';
      default:
        return 'Profile';
    }
  }

  IconButton? _getLeadingIcon() {
    if (selectedBatchId != null || selectedBranchId != null) {
      return IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          setState(() {
            if (selectedBatchId != null) {
              selectedBatchId = null;
            } else {
              selectedBranchId = null;
            }
          });
        },
      );
    }
    return null;
  }

  List<Widget>? _getAppBarActions() {
    if (selectedBatchId != null) {
      return [
        IconButton(
          icon: Icon(showingStudents ? Icons.subject : Icons.person),
          onPressed: () {
            setState(() {
              showingStudents = !showingStudents;
              showingStudents ? null : fetchClassesOfBatch(selectedBatchId!);
            });
          },
        ),
      ];
    }
    return null;
  }

  Widget _getBody() {
    if (_selectedIndex == 0) {
      if (selectedBatchId != null) {
        return showingStudents ? _buildStudentsList() : _buildClassesList();
      } else {
        return selectedBranchId == null
            ? _buildBranchesList()
            : _buildBatchesList();
      }
    }
    switch (_selectedIndex) {
      case 1:
        return _buildSubjectsList();
      case 2:
        return _buildTeachersList();
      default:
        return _buildProfileScreen();
    }
  }

  FloatingActionButton _getFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _onFloatingActionButtonPressed,
      backgroundColor: Colors.blue,
      icon: Icon(
          _selectedIndex == 3 ? Icons.account_circle_outlined : Icons.add,
          color: Colors.white),
      label: Text(
        _getFloatingActionButtonLabel(),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  void _onFloatingActionButtonPressed() {
    if (_selectedIndex == 0) {
      if (selectedBranchId == null) {
        _showAddBranchDialog();
      } else if (selectedBatchId == null) {
        _showAddBatchDialog();
      } else {
        showingStudents ? _showAddStudentDialog() : _showAddClassDialog();
      }
    } else if (_selectedIndex == 1) {
      _showAddSubjectDialog();
    } else if (_selectedIndex == 2) {
      _showAddTeacherDialog();
    } else {
      logout();
    }
  }

  String _getFloatingActionButtonLabel() {
    if (selectedBatchId != null) {
      return showingStudents ? 'Add Student' : 'Add Class';
    }
    if (selectedBranchId != null) {
      return 'Add Batch';
    }
    switch (_selectedIndex) {
      case 0:
        return 'Add Branch';
      case 1:
        return 'Add Subject';
      case 2:
        return 'Add Teacher';
      default:
        return "Log Out";
    }
  }

  BottomNavigationBar _buildBottomNavigationBar() {
    return BottomNavigationBar(
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(icon: Icon(Icons.business), label: 'Branches'),
        BottomNavigationBarItem(icon: Icon(Icons.subject), label: 'Subjects'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Teachers'),
        BottomNavigationBarItem(
            icon: Icon(Icons.account_circle), label: 'Profile'),
      ],
      currentIndex: _selectedIndex,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
          selectedBranchId = null;
          selectedBatchId = null;
        });
      },
    );
  }

  void _showDialog(String title, Widget content, VoidCallback onSubmit) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: content,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            TextButton(
              onPressed: onSubmit,
              child: const Text(
                'Add',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool capital = false,
    int maxChars = 100,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      inputFormatters: [
        // Apply the character limit formatter
        LengthLimitingTextInputFormatter(maxChars),
        // Only apply the uppercase formatter if capital is true
        if (capital)
          TextInputFormatter.withFunction(
            (oldValue, newValue) => TextEditingValue(
              text: newValue.text.toUpperCase(), // Convert text to uppercase
              selection: newValue.selection,
            ),
          ),
      ],
    );
  }

  void _showAddBranchDialog() {
    const int maxYears = 5;
    int? selectedCourseDuration;
    final TextEditingController branchController = TextEditingController();

    _showDialog(
      'Add New Branch',
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Branch Name Input Field
              _buildTextField(
                controller: branchController,
                label: 'Branch Name',
                capital: true, // Ensures input is capitalized
              ),
              const SizedBox(height: 16.0),

              // Course Duration Selection
              const Text("Select Course Duration (Years):",
                  style: TextStyle(fontSize: 14.0)),
              const SizedBox(height: 8.0),
              Wrap(
                spacing: 8.0,
                children: List<Widget>.generate(maxYears, (index) {
                  int year = index + 1;
                  bool isSelected = selectedCourseDuration == year;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedCourseDuration = year;
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? Colors.blue : Colors.grey[200],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        year.toString(),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontSize: 14.0,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
      () {
        if (branchController.text.isNotEmpty &&
            selectedCourseDuration != null) {
          _addBranch(branchController.text, selectedCourseDuration!);
          Navigator.of(context).pop();
        }
      },
    );
  }

  void _showAddBatchDialog() {
    String? selectedBatch;
    final List<String> batches = ['A', 'B', 'C'];
    final batchOfController = TextEditingController();

    _showDialog(
      'Add New Batch',
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16.0),
              _buildTextField(
                  controller: batchOfController,
                  label: 'Batch Of',
                  maxChars: 4),
              const SizedBox(height: 16.0),
              const Text("Select Batch:", style: TextStyle(fontSize: 14.0)),
              const SizedBox(height: 8.0),
              Wrap(
                spacing: 8.0,
                children: batches.map((batch) {
                  bool isSelected = selectedBatch == batch;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedBatch = batch;
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? Colors.blue : Colors.grey[200],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        batch,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontSize: 14.0,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
      () {
        if (selectedBatch != null && batchOfController.text.isNotEmpty) {
          _addBatch(
            selectedBatch ?? "A",
            batchOfController.text,
          );
          Navigator.of(context).pop();
        }
      },
    );
  }

  void _showAddClassDialog() {
    int? selectedYear;
    String? selectedSemesterType;

    _showDialog(
      'Create New Class',
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Year Selection
              const Text("Select Year:", style: TextStyle(fontSize: 14.0)),
              const SizedBox(height: 8.0),
              Wrap(
                spacing: 8.0,
                children: List<Widget>.generate(maxYears!, (index) {
                  int year = index + 1;
                  bool isSelected = selectedYear == year;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedYear = year;
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? Colors.blue : Colors.grey[200],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        year.toString(),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontSize: 14.0,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16.0),

              // Semester Type Selection
              const Text("Select Semester Type:", style: TextStyle(fontSize: 14.0)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: semesterTypes.map((type) {
                  return RadioListTile<String>(
                    title: Text(type),
                    value: type,
                    groupValue: selectedSemesterType,
                    onChanged: (newValue) {
                      setState(() {
                        selectedSemesterType = newValue;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: Colors.blue,
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
      () {
        // Validation before adding the class
        if (selectedYear != null && selectedSemesterType != null) {
          _addClass(
            selectedYear, // Pass selected year as string
            selectedSemesterType?[0],
          );
          Navigator.of(context)
              .pop(); // Close the dialog after adding the class
        } else {
          // Show an error if either of the fields is not selected
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please select both year and semester type')),
          );
        }
      },
    );
  }

  void _showAddStudentDialog() {
    final studentIdController = TextEditingController();
    final studentNameController = TextEditingController();
    final studentSurnameController = TextEditingController();
    final studentEmailController = TextEditingController();

    _showDialog(
      'Add New Student',
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTextField(controller: studentIdController, label: 'Student ID'),
          _buildTextField(
              controller: studentNameController, label: 'First Name'),
          _buildTextField(
              controller: studentSurnameController, label: 'Last Name'),
          _buildTextField(controller: studentEmailController, label: 'Email'),
        ],
      ),
      () {
        if (studentIdController.text.isNotEmpty &&
            studentNameController.text.isNotEmpty &&
            studentSurnameController.text.isNotEmpty &&
            studentEmailController.text.isNotEmpty) {
          _addStudent(
            studentIdController.text,
            studentNameController.text,
            studentSurnameController.text,
            studentEmailController.text,
          );
          Navigator.of(context).pop(); // Close dialog after adding
        }
      },
    );
  }

  void _showAssignSubjectsDialog(int classId) {
    String? selectedSubjectCode;
    int? selectedTeacherId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Assign Subject to Class'),
              content: SingleChildScrollView(
                // Wrap in SingleChildScrollView
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Select Subject'),
                      items: subjects.map((subject) {
                        return DropdownMenuItem<String>(
                          value: subject.subjectCode,
                          child: Text(
                            subject.subjectName,
                            overflow: TextOverflow.ellipsis, // Prevent overflow
                          ),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          selectedSubjectCode = newValue;
                        });
                      },
                      value: selectedSubjectCode,
                    ),
                    const SizedBox(height: 16.0),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Select Teacher'),
                      items: teachers.map((teacher) {
                        return DropdownMenuItem<int>(
                          value: teacher.teacherId,
                          child: Text(
                            '${teacher.teacherName} ${teacher.teacherSurname}',
                            overflow: TextOverflow.ellipsis, // Prevent overflow
                          ),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          selectedTeacherId = newValue;
                        });
                      },
                      value: selectedTeacherId,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (selectedSubjectCode != null &&
                        selectedTeacherId != null) {
                      assignSubjectToClass(
                          classId, selectedSubjectCode!, selectedTeacherId!);
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showTimetableDialog(BuildContext context, int classId,
      String subjectName, String subjectCode) {
    List<Timetable> entries = cachedClassTimetable[classId] ?? [];

    List<Timetable> subjectEntries =
        entries.where((entry) => entry.subjectCode == subjectCode).toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            subjectName,
            style: const TextStyle(fontSize: 20.0),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Existing Timetable Entries:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                if (subjectEntries.isEmpty)
                  const Text("No existing entries for this subject."),
                if (subjectEntries.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: subjectEntries.length,
                    itemBuilder: (context, index) {
                      final entry = subjectEntries[index];
                      return _buildCardTile(entry.day, subHeadings: [
                        'Time: ${entry.startTime} : ${entry.endTime}',
                        'Room: ${entry.roomNumber}'
                      ]);
                    },
                  ),
                  const Divider(height: 24.0),
                const SizedBox(height: 16.0),
                buildNewTimetableEntryForm(context, classId, subjectCode),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddSubjectDialog() {
    final subjectCodeController = TextEditingController();
    final subjectNameController = TextEditingController();

    _showDialog(
      'Add New Subject',
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTextField(
              controller: subjectCodeController,
              label: 'Subject Code',
              capital: true),
          _buildTextField(
              controller: subjectNameController, label: 'Subject Name'),
        ],
      ),
      () {
        if (subjectCodeController.text.isNotEmpty &&
            subjectNameController.text.isNotEmpty) {
          _addSubject(
            subjectCodeController.text,
            subjectNameController.text,
          );
          Navigator.of(context).pop(); // Close dialog after adding
        }
      },
    );
  }

  void _showAddTeacherDialog() {
    final teacherNameController = TextEditingController();
    final teacherSurnameController = TextEditingController();
    final teacherEmailController = TextEditingController();

    _showDialog(
      'Add New Teacher',
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTextField(
              controller: teacherNameController, label: 'First Name'),
          _buildTextField(
              controller: teacherSurnameController, label: 'Last Name'),
          _buildTextField(controller: teacherEmailController, label: 'Email'),
        ],
      ),
      () {
        if (teacherNameController.text.isNotEmpty &&
            teacherSurnameController.text.isNotEmpty &&
            teacherEmailController.text.isNotEmpty) {
          _addTeacher(
            teacherNameController.text,
            teacherSurnameController.text,
            teacherEmailController.text,
          );
          Navigator.of(context).pop(); // Close dialog after adding
        }
      },
    );
  }

  Future<void> _addBranch(String branchName, int courseDuration) async {
    try {
      final response = await api_service.postApiRequest('/admin/branches', {
        'branch_name': branchName,
        'course_duration': courseDuration,
      });
      if (response.statusCode == 201) {
        fetchBranches(forceRefresh: true); // Refresh branch list
      }
    } catch (e) {
      "";
    }
  }

  Future<void> _addBatch(String batch, String batchOf) async {
    if (selectedBranchId != null) {
      try {
        final response = await api_service.postApiRequest('/admin/batches', {
          'branch_id': selectedBranchId,
          'batch_of': batchOf,
          'batch': batch,
        });
        if (response.statusCode == 201) {
          fetchBatchesOfBranch(selectedBranchId!, maxYears!,
              forceRefresh: true); // Refresh batches for the branch
        }
      } catch (e) {
        "";
      }
    }
  }

  Future<void> _addClass(int? year, String? semesterType) async {
    if (selectedBatchId != null) {
      try {
        final response = await api_service.postApiRequest('/admin/classes', {
          'batch_id': selectedBatchId,
          'year': year,
          'semester_type': semesterType,
        });
        if (response.statusCode == 201) {
          fetchClassesOfBatch(selectedBatchId!, forceRefresh: true);
        }
      } catch (e) {
        "";
      }
    }
  }

  Future<void> _addStudent(
      String studentId, String name, String surname, String email) async {
    if (selectedBatchId != null) {
      try {
        final response = await api_service.postApiRequest('/admin/students', {
          'student_id': studentId,
          'student_name': name,
          'student_surname': surname,
          'student_email': email,
          'batch_id': selectedBatchId,
        });
        if (response.statusCode == 201) {
          fetchStudentsOfBatch(selectedBatchId!, forceRefresh: true);
        }
      } catch (e) {
        "";
      }
    }
  }

  Future<void> assignSubjectToClass(
      int classId, String subjectCode, int teacherId) async {
    try {
      final response =
          await api_service.postApiRequest('/admin/assign_subject', {
        'class_id': classId,
        'subject_code': subjectCode,
        'teacher_id': teacherId,
      });
      if (response.statusCode == 201) {
        fetchSubjectsOfClass(classId, forceRefresh: true);
      }
    } catch (e) {
      "";
    }
  }

  Future<void> _addTimetableEntry(int classId, String subjectCode,
      String startTime, String endTime, String roomNumber, String day) async {
    try {
      final response = await api_service.postApiRequest('/admin/timetable', {
        'class_id': classId,
        'subject_code': subjectCode,
        'start_time': startTime,
        'end_time': endTime,
        'room_number': roomNumber,
        'day': day,
      });
      if (response.statusCode == 201) {
        fetchTimetableOfClass(classId,
            forceRefresh: true); // Refresh the timetable after adding
      } else {
        "";
      }
    } catch (e) {
      "";
    }
  }

  Future<void> _addSubject(String subjectCode, String subjectName) async {
    try {
      final response = await api_service.postApiRequest('/admin/subjects', {
        'subject_code': subjectCode,
        'subject_name': subjectName,
      });
      if (response.statusCode == 201) {
        fetchSubjects(forceRefresh: true);
      }
    } catch (e) {
      "";
    }
  }

  Future<void> _addTeacher(String name, String surname, String email) async {
    try {
      final response = await api_service.postApiRequest('/admin/teachers', {
        'teacher_name': name,
        'teacher_surname': surname,
        'teacher_email': email,
      });
      if (response.statusCode == 201) {
        fetchTeachers(forceRefresh: true);
      }
    } catch (e) {
      "";
    }
  }
}
