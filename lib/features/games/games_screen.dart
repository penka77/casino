import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'roulette/roulette_screen.dart';
import 'poker/poker_screen.dart';
import 'coin_flip/coin_flip_screen.dart';
import 'dice/dice_screen.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Игры'),
        backgroundColor: Colors.blue[900],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Выберите игру',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
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