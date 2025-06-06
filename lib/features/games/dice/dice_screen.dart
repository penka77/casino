import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math';
import '../../auth/auth_service.dart';
import '../../../core/database/database_helper.dart';
import '../../auth/login_screen.dart';

class Dice extends StatefulWidget {
  const Dice({super.key});

  @override
  State<Dice> createState() => _DiceState();
}

class _DiceState extends State<Dice> with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _dbHelper = DatabaseHelper.instance;
  Map<String, dynamic>? _user;
  final TextEditingController betAmountController = TextEditingController();
  bool isRolling = false;
  int? result;
  int? selectedNumber;
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller)
      ..addListener(() {
        setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _checkResult();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    betAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
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

  void _rollDice() {
    if (isRolling || selectedNumber == null || betAmountController.text.isEmpty) {
      Get.snackbar(
        'Ошибка',
        'Выберите число и введите сумму ставки',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    int betAmount = int.tryParse(betAmountController.text) ?? 0;
    if (_user == null || betAmount <= 0 || betAmount > _user!['balance']) {
      Get.snackbar(
        'Ошибка',
        'Введите корректную сумму ставки или у вас недостаточно средств',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      isRolling = true;
      result = null;
    });

    _controller.reset();
    _controller.forward();
  }

  void _checkResult() async {
    final random = Random().nextInt(6) + 1;
    setState(() {
      result = random;
      isRolling = false;
    });

    int betAmount = int.tryParse(betAmountController.text) ?? 0;
    bool won = random == selectedNumber;
    double winAmount = won ? betAmount * 5.0 : 0.0;

    if (_user != null) {
      final newBalance = _user!['balance'] + (won ? winAmount : -betAmount);
      await _dbHelper.updateUserBalance(_user!['id'], newBalance);

      // Save game history
      await _dbHelper.addGameHistory({
        'user_id': _user!['id'],
        'game_type': 'dice',
        'bet_amount': betAmount.toDouble(),
        'win_amount': winAmount,
        'result': random.toString(),
        'created_at': DateTime.now().toIso8601String(),
      });

      // Обновляем прогресс испытаний
      await _authService.updateChallengeProgress(
        _user!['id'],
        'dice',
        'play_games',
        1.0,
      );

      if (won) {
        await _authService.updateChallengeProgress(
          _user!['id'],
          'dice',
          'win',
          1.0,
        );

        await _authService.updateChallengeProgress(
          _user!['id'],
          'dice',
          'win_amount',
          winAmount,
        );
      }

      await _authService.updateChallengeProgress(
        _user!['id'],
        'dice',
        'bet_amount',
        betAmount.toDouble(),
      );

      setState(() {
        _user!['balance'] = newBalance;
      });
      
      _showResultDialog(
        won ? "Поздравляем!" : "Удачи в следующий раз!",
        "Выпало число: $random\n${won ? 'Вы выиграли ${winAmount.toStringAsFixed(0)} монет!' : 'Вы проиграли ${betAmount.toStringAsFixed(0)} монет'}"
      );
    }

    setState(() {
      selectedNumber = null;
      betAmountController.clear();
    });
  }

  void _showResultDialog(String title, String content) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            margin: const EdgeInsets.only(top: 45),
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              gradient: LinearGradient(
                colors: [
                  Colors.blue[900]!,
                  Colors.purple[900]!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  offset: Offset(0, 10),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    ),
                    child: Text(
                      "OK",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
        title: const Text('Кости'),
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
                      _buildDice(),
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

  Widget _buildDice() {
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
            ..rotateX(_animation.value * pi * 2)
            ..rotateY(_animation.value * pi * 2),
          alignment: Alignment.center,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
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
                      Icons.casino,
                      size: 50,
                      color: Colors.blue,
                    )
                  : Text(
                      result.toString(),
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
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
              _buildNumberButton(1),
              _buildNumberButton(2),
              _buildNumberButton(3),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNumberButton(4),
              _buildNumberButton(5),
              _buildNumberButton(6),
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
            onPressed: isRolling ? null : _rollDice,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isRolling ? 'Бросаем кости...' : 'Бросить кости',
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

  Widget _buildNumberButton(int number) {
    final isSelected = selectedNumber == number;
    return ElevatedButton(
      onPressed: isRolling
          ? null
          : () {
              setState(() {
                selectedNumber = number;
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
        number.toString(),
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }
} 