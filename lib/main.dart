import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roulette/features/auth/auth_service.dart';
import 'package:roulette/features/auth/login_screen.dart';
import 'package:roulette/features/profile/profile_screen.dart';
import 'package:roulette/core/database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Казино',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: FutureBuilder<bool>(
        future: AuthService().isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return snapshot.data == true ? const ProfileScreen() : const LoginScreen();
        },
      ),
    );
  }
}
