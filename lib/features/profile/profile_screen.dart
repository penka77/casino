import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../games/games_screen.dart';
import '../history/history_screen.dart';
import '../cashier/cashier_screen.dart';
import '../../core/database/database_helper.dart';
import '../challenges/challenges_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  bool _isEditing = false;
  String? _avatarUrl;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        setState(() {
          _user = user;
          _usernameController.text = user['username'] ?? '';
          _emailController.text = user['email'] ?? '';
          _avatarUrl = user['avatar_url'];
          _isLoading = false;
        });
      } else {
        Get.offAll(() => const LoginScreen());
      }
    } catch (e) {
      print('Error loading user data: $e');
      Get.snackbar(
        'Ошибка',
        'Не удалось загрузить данные пользователя',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _authService.logout();
      Get.offAll(() => const LoginScreen());
    } catch (e) {
      Get.snackbar(
        'Ошибка',
        'Не удалось выйти из аккаунта',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[900]!,
              Colors.purple[900]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Профиль',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: _handleLogout,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserInfo(),
                      const SizedBox(height: 24),
                      _buildNavigationButtons(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white.withOpacity(0.2),
                backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                child: _avatarUrl == null
                    ? const Icon(Icons.person, size: 40, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _user?['username'] ?? 'Пользователь',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _user?['email'] ?? '',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Баланс', '${_user?['balance']?.toStringAsFixed(0) ?? '0'} монет'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Column(
      children: [
        _buildNavigationButton(
          'Игры',
          Icons.casino,
          () => Get.to(() => const GamesScreen()),
        ),
        const SizedBox(height: 16),
        _buildNavigationButton(
          'История игр',
          Icons.history,
          () => Get.to(() => const HistoryScreen()),
        ),
        const SizedBox(height: 16),
        _buildNavigationButton(
          'Испытания',
          Icons.emoji_events,
          () => Get.to(() => const ChallengesScreen()),
        ),
        const SizedBox(height: 16),
        _buildNavigationButton(
          'Пополнить баланс',
          Icons.account_balance_wallet,
          () => Get.to(() => const CashierScreen()),
        ),
      ],
    );
  }

  Widget _buildNavigationButton(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: Colors.white,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

