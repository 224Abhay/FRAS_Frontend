import 'package:shared_preferences/shared_preferences.dart';

class Admin {
  final int adminId;
  final String adminName;
  final String adminSurname;
  final String adminEmail;

  Admin({
    required this.adminId,
    required this.adminName,
    required this.adminSurname,
    required this.adminEmail,
  });

  static Future<Admin> fromSP() async {
    final userDetails = await SharedPreferences.getInstance();
    return Admin(
      adminId: userDetails.getInt('admin_id') ?? 0,
      adminName: userDetails.getString('admin_name') ?? "Unknown",
      adminSurname: userDetails.getString('admin_surname') ?? "Unknown",
      adminEmail: userDetails.getString('admin_email') ?? "Unknown",
    );
  }
}
