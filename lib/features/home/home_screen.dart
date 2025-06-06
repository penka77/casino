import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../profile/profile_screen.dart';
import '../games/roulette/roulette_screen.dart';
import '../games/poker/poker_screen.dart';
import '../games/coin_flip/coin_flip_screen.dart';
import '../games/dice/dice_screen.dart';
import '../auth/auth_service.dart';
import '../../core/database/database_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _dbHelper = DatabaseHelper.instance;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        setState(() {
          _user = user;
        });
      }
    } catch (e) {
      Get.snackbar(
        'Ошибка',
        'Не удалось загрузить данные пользователя',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Казино'),
        backgroundColor: Colors.blue[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Get.to(() => const ProfileScreen()),
          ),
        ],
      ),
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
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Баланс: ${_user?['balance']?.toStringAsFixed(0) ?? '0'} монет',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  padding: const EdgeInsets.all(16),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _buildGameCard(
                      'Рулетка',
                      'Классическая европейская рулетка',
                      Icons.casino,
                      () => Get.to(() => const Roulette()),
                    ),
                    _buildGameCard(
                      'Покер',
                      'Техасский Холдем',
                      Icons.sports_esports,
                      () => Get.to(() => const PokerScreen()),
                    ),
                    _buildGameCard(
                      'Орел и Решка',
                      'Простая игра на удачу',
                      Icons.monetization_on,
                      () => Get.to(() => const CoinFlip()),
                    ),
                    _buildGameCard(
                      'Кости',
                      'Бросьте кости и угадайте число',
                      Icons.casino_outlined,
                      () => Get.to(() => const Dice()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard(String title, String description, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue[900]!,
                Colors.purple[900]!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 