import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math';
import '../../auth/auth_service.dart';
import '../../../core/database/database_helper.dart';
import '../../auth/login_screen.dart';

class CoinFlip extends StatefulWidget {
  const CoinFlip({super.key});

  @override
  State<CoinFlip> createState() => _CoinFlipState();
}

class _CoinFlipState extends State<CoinFlip> with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _dbHelper = DatabaseHelper.instance;
  Map<String, dynamic>? _user;
  final TextEditingController betAmountController = TextEditingController();
  bool isFlipping = false;
  bool? result;
  String? selectedSide;
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isLoading = true;
  int _flipCount = 0;
  final int _totalFlips = 5;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller)
      ..addListener(() {
        setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _handleFlipComplete();
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserData(); // Обновляем данные при возвращении на экран
  }

  @override
  void dispose() {
    _controller.dispose();
    betAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        setState(() {
          _user = user;
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

  Future<void> _updateBalance(double newBalance) async {
    if (_user != null) {
      await _dbHelper.updateUserBalance(_user!['id'], newBalance);
      setState(() {
        _user!['balance'] = newBalance;
      });
    }
  }

  void _handleFlip() {
    if (isFlipping) return;
    if (selectedSide == null || int.tryParse(betAmountController.text) == null || int.tryParse(betAmountController.text)! <= 0) {
      Get.snackbar(
        'Ошибка',
        'Пожалуйста, сделайте ставку',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    int betAmount = int.tryParse(betAmountController.text)!;
    if (_user == null || betAmount <= 0 || betAmount > _user!['balance']) {
      Get.snackbar(
        'Ошибка',
        'Введите корректную сумму ставки или у вас недостаточно средств',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // Сразу списываем ставку и обновляем UI
    double newBalance = _user!['balance'] - betAmount;
    _updateBalance(newBalance);

    setState(() {
      isFlipping = true;
      result = null;
      _flipCount = 0;
    });

    _controller.reset();
    _controller.forward();
  }

  void _handleFlipComplete() {
    if (_flipCount < _totalFlips) {
      setState(() {
        _flipCount++;
      });
      _controller.reset();
      _controller.forward();
    } else {
      _checkResult();
    }
  }

  void _checkResult() async {
    final random = Random();
    final result = random.nextBool() ? 'Орел' : 'Решка';
    
    double betAmount = int.tryParse(betAmountController.text)!.toDouble();
    double winAmount = 0;
    bool isWin = false;

    if (selectedSide == result) {
      winAmount = betAmount * 2;
      isWin = true;
      // Немедленно обновляем баланс при выигрыше
      double newBalance = _user!['balance'] + winAmount;
      await _updateBalance(newBalance);
    }

    if (_user != null) {
      // Сохраняем историю игры с более подробной информацией
      await _dbHelper.addGameHistory({
        'user_id': _user!['id'],
        'game_type': 'coin_flip',
        'bet_amount': betAmount,
        'win_amount': winAmount,
        'result': isWin ? 'win' : 'lose',
        'selected_side': selectedSide,
        'actual_side': result,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Обновляем прогресс испытаний
      await _authService.updateChallengeProgress(
        _user!['id'],
        'coin_flip',
        'play_games',
        1.0,
      );

      if (isWin) {
        await _authService.updateChallengeProgress(
          _user!['id'],
          'coin_flip',
          'win',
          1.0,
        );

        await _authService.updateChallengeProgress(
          _user!['id'],
          'coin_flip',
          'win_amount',
          winAmount,
        );
      }

      await _authService.updateChallengeProgress(
        _user!['id'],
        'coin_flip',
        'bet_amount',
        betAmount,
      );

      setState(() {
        this.result = result == 'Орел';
      });
      
      String message = isWin
          ? 'Поздравляем! Вы выиграли ${winAmount.toStringAsFixed(0)} монет'
          : 'К сожалению, вы проиграли ${betAmount.toStringAsFixed(0)} монет';

      Get.snackbar(
        'Результат',
        message,
        backgroundColor: isWin ? Colors.green : Colors.red,
        colorText: Colors.white,
      );
    }

    setState(() {
      isFlipping = false;
      betAmountController.clear();
      selectedSide = null;
    });
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
      appBar: AppBar(
        title: const Text('Орел и Решка'),
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildCoin(),
                      const SizedBox(height: 24),
                      _buildBettingControls(),
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

  Widget _buildCoin() {
    return Container(
      height: 200,
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(_animation.value * pi),
          alignment: Alignment.center,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.amber,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: result == null
                  ? const Icon(
                      Icons.monetization_on,
                      size: 80,
                      color: Colors.white,
                    )
                  : Transform(
                      transform: Matrix4.identity()
                        ..rotateX(result! ? pi : 0),
                      alignment: Alignment.center,
                      child: Text(
                        result! ? 'Орёл' : 'Решка',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBettingControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Сделайте ставку',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSideButton('Орел'),
              _buildSideButton('Решка'),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: betAmountController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Сумма ставки',
              labelStyle: const TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white30),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isFlipping ? null : _handleFlip,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isFlipping ? 'Подбрасываем...' : 'Подбросить монетку',
              style: TextStyle(
                color: Colors.blue[900],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideButton(String side) {
    final isSelected = selectedSide == side;
    return ElevatedButton(
      onPressed: isFlipping
          ? null
          : () {
              setState(() {
                selectedSide = side;
              });
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.green : Colors.white.withOpacity(0.2),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        side,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
} 