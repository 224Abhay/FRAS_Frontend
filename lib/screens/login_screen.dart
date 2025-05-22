import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main_screen_admin.dart';
import 'main_screen_student.dart';
import 'main_screen_teacher.dart';
import '../services/api_service.dart' as api_service;
import 'package:shared_preferences/shared_preferences.dart';

bool _validateInput(BuildContext context, email, password) {
  ScaffoldMessenger.of(context).clearSnackBars();

  bool validateEmail(String email) {
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  bool validatePassword(String password) {
    return password.length >= 8;
  }

  if (email.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter your email.')),
    );
    return false;
    // }else if(!validateEmail(email)){
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('Please enter a valid email.')),
    //   );
    //   return false;
  }

  if (password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter your password.')),
    );
    return false;
  } else if (!validatePassword(password)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content:
              Text('Incorrect Password. They are at least 8 characters long.')),
    );
    return false;
  }
  return true;
}

Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  bool upperOnly = false,
  bool lowerOnly = false,
  int maxChars = 100,
  bool hideText = false,
}) {
  return TextField(
    controller: controller,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        // borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(
            color: Colors.blue, width: 2), // Blue border when focused
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    ),
    inputFormatters: [
      // Apply the character limit formatter
      LengthLimitingTextInputFormatter(maxChars),
      // Only apply the uppercase formatter if capital is true
      if (upperOnly)
        TextInputFormatter.withFunction(
          (oldValue, newValue) => TextEditingValue(
            text: newValue.text.toUpperCase(), // Convert text to uppercase
            selection: newValue.selection,
          ),
        ),
      if (lowerOnly)
        TextInputFormatter.withFunction(
          (oldValue, newValue) => TextEditingValue(
            text: newValue.text.toLowerCase(), // Convert text to uppercase
            selection: newValue.selection,
          ),
        ),
    ],
    obscureText: hideText,
  );
}

Future<void> handleLoginResponse(
    BuildContext context, String responseBody) async {
  var responseData = jsonDecode(responseBody);

  SharedPreferences credentials = await SharedPreferences.getInstance();
  await credentials.setString('access_token', responseData['access_token']);
  await credentials.setString('refresh_token', responseData['refresh_token']);

  SharedPreferences userDetails = await SharedPreferences.getInstance();
  String role = responseData['role'];
  await userDetails.setString('role', role);

  responseData['user_details'].forEach((key, value) {
    if (value is int) {
      userDetails.setInt('$key', value);
    } else if (value is String) {
      userDetails.setString('$key', value);
    } else if (value is List) {
      userDetails.setString('$key', jsonEncode(value));
    }
  });

  if (!context.mounted) return;

  if (role == 'admin') {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AdminMainScreen()),
      (Route<dynamic> route) => false, // Clears the stack
    );
  } else if (role == 'student') {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const StudentMainScreen()),
      (Route<dynamic> route) => false,
    );
  } else if (role == 'teacher') {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const TeacherMainScreen()),
      (Route<dynamic> route) => false,
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmationCodeController =
      TextEditingController();
  bool isLoading = false;
  bool isRegistrationStep = false;
  bool isConfirmationStep = false;

  Future<void> login() async {
    if (!_validateInput(
        context, emailController.text, passwordController.text)) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    final response = await api_service.postApiRequest("/auth/login", {
      'email_id': emailController.text,
      'password': passwordController.text,
    });

    if (!mounted) return;

    if (response.statusCode == 200) {
      handleLoginResponse(context, response.body);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful')),
      );
    } else if (response.statusCode == 401 || response.statusCode == 404) {
      var errorData = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorData['message'] ?? 'Invalid credentials')),
      );
    } else if (response.statusCode == 503) {
      var errorData = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorData['message'])),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed')),
      );
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2970FE),
                  ),
                ),
                const SizedBox(height: 20),

                _buildTextField(
                    controller: emailController,
                    label: "Email",
                    lowerOnly: true),

                const SizedBox(height: 20),

                _buildTextField(
                    controller: passwordController,
                    label: "Password",
                    hideText: true),

                const SizedBox(height: 30),

                isLoading
                    ? const CircularProgressIndicator(color: Color(0xFF2970FE))
                    : ElevatedButton(
                        onPressed: login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF2970FE), // Custom green color
                          padding: const EdgeInsets.symmetric(
                              horizontal: 80, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                const SizedBox(height: 20),

                // Register Link
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const RegisterScreen()), // Go to register page
                    );
                  },
                  child: const Text(
                    'Register here',
                    style: TextStyle(
                      // color: Colors.white,
                      decoration: TextDecoration.underline,
                      color: Color(0xD22970FE),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  RegisterScreenState createState() => RegisterScreenState();
}

class RegisterScreenState extends State<RegisterScreen> {
  bool isLoading = false;
  bool isConfirmationStep = false;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmationCodeController =
      TextEditingController();

  Future<void> register() async {
    if (!_validateInput(
        context, emailController.text, passwordController.text)) {
      return;
    }
    setState(() {
      isLoading = true;
    });

    final response =
        await api_service.postApiRequest("/auth/verification_code", {
      'email_id': emailController.text,
      'password': passwordController.text,
    });

    if (!mounted) return;

    if (response.statusCode == 200) {
      setState(() {
        isConfirmationStep = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('A confirmation code has been sent to your email.')),
      );
    } else {
      // Handle errors
      var errorData = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorData['message'] ?? 'An error occurred')),
      );
    }
    setState(() {
      isLoading = false;
    });
  }

  // Confirm the verification code
  Future<void> confirmCode() async {
    setState(() {
      isLoading = true;
    });

    final response = await api_service.postApiRequest("/auth/confirm_code", {
      'email_id': emailController.text,
      'password': passwordController.text,
      'confirmation_code': confirmationCodeController.text,
    });

    if (!mounted) return;

    if (response.statusCode == 200) {
      handleLoginResponse(context, response.body);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration confirmed successfully')),
      );
    } else {
      // Handle errors
      var errorData = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(errorData['message'] ?? 'Invalid confirmation code')),
      );
    }
    setState(() {
      isLoading = false;
    });
  }

  // Resend confirmation code
  Future<void> resendCode() async {
    setState(() {
      isLoading = true;
    });

    final response =
        await api_service.postApiRequest("/auth/verification_code", {
      'email_id': emailController.text,
      'password': passwordController.text,
    });

    if (!mounted) return;

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('A new confirmation code has been sent to your email.')),
      );
    } else {
      var errorData = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorData['message'] ?? 'An error occurred')),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.white),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Register',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2970FE),
                  ),
                ),
                const SizedBox(height: 20),
                // Registration Step
                if (!isConfirmationStep) ...[
                  _buildTextField(
                      controller: emailController,
                      label: "Email",
                      lowerOnly: true),
                  const SizedBox(height: 20),
                  _buildTextField(
                      controller: passwordController,
                      label: "Password",
                      hideText: true),
                  const SizedBox(height: 30),
                  isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2970FE),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 80, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'Register',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                ],
                // Confirmation Step
                if (isConfirmationStep) ...[
                  TextField(
                    controller: confirmationCodeController,
                    decoration: InputDecoration(
                      labelText: 'Confirmation Code',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                  const SizedBox(height: 20),
                  isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: confirmCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2970FE),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 80, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'Confirm Code',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                  const SizedBox(height: 20),
                  // Resend Code Button
                  TextButton(
                    onPressed: resendCode,
                    child: const Text('Resend Code',
                        style: TextStyle(color: Color(0xFF2970FE))),
                  ),
                  const SizedBox(height: 30),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
