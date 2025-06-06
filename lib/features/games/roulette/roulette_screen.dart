import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:async';
import '../../auth/auth_service.dart';
import '../../../core/database/database_helper.dart';
import '../../auth/login_screen.dart';

class Roulette extends StatefulWidget {
  const Roulette({super.key});

  @override
  State<Roulette> createState() => _RouletteState();
}

class _RouletteState extends State<Roulette> {
  final _authService = AuthService();
  final _dbHelper = DatabaseHelper.instance;
  final selected = BehaviorSubject<int>.seeded(0);
  Map<String, dynamic>? _user;
  List<String> selectedBets = [];
  final TextEditingController betAmountController = TextEditingController();
  bool isLocked = false;
  Timer? countdownTimer;
  int timeLeft = 30;
  bool _isLoading = true;

  List<int> items = [
    0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5,
    24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    selected.close();
    betAmountController.dispose();
    countdownTimer?.cancel();
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
          startBettingPhase();
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

  void checkBetOutcome(int result) async {
    if (_user == null) return;

    int totalPayout = 0;
    int betAmount = int.tryParse(betAmountController.text) ?? 0;

    if (selectedBets.isNotEmpty && betAmount > 0) {
      // Check if user has enough balance
      if (_user!['balance'] < betAmount) {
        _showResultDialog(
          context,
          "Ошибка",
          "Недостаточно средств для ставки"
        );
        return;
      }

      for (String bet in selectedBets) {
        bool won = false;
        int payoutMultiplier = 0;

        switch (bet) {
          case '0':
            won = (result == 0);
            payoutMultiplier = 36;
            break;
          case '1-12':
            won = (result >= 1 && result <= 12);
            payoutMultiplier = 3;
            break;
          case '13-24':
            won = (result >= 13 && result <= 24);
            payoutMultiplier = 3;
            break;
          case '25-36':
            won = (result >= 25 && result <= 36);
            payoutMultiplier = 3;
            break;
          case 'Red':
            won = result != 0 && items.indexOf(result).isOdd;
            payoutMultiplier = 2;
            break;
          case 'Black':
            won = result != 0 && items.indexOf(result).isEven;
            payoutMultiplier = 2;
            break;
          case 'Odd':
            won = (result != 0 && result % 2 != 0);
            payoutMultiplier = 2;
            break;
          case 'Even':
            won = (result != 0 && result % 2 == 0);
            payoutMultiplier = 2;
            break;
        }

        if (won) {
          totalPayout += betAmount * payoutMultiplier;
        }
      }

      if (totalPayout > 0) {
        final newBalance = _user!['balance'] + totalPayout;
        await _dbHelper.updateUserBalance(_user!['id'], newBalance);
        await _dbHelper.addGameHistory({
          'user_id': _user!['id'],
          'game_type': 'roulette',
          'bet_amount': betAmount.toDouble(),
          'win_amount': totalPayout.toDouble(),
          'result': 'win',
          'created_at': DateTime.now().toIso8601String(),
        });
        
        // Обновляем прогресс испытаний
        await _authService.updateChallengeProgress(
          _user!['id'],
          'roulette',
          'play_games',
          1.0,
        );

        await _authService.updateChallengeProgress(
          _user!['id'],
          'roulette',
          'win',
          1.0,
        );

        await _authService.updateChallengeProgress(
          _user!['id'],
          'roulette',
          'win_amount',
          totalPayout.toDouble(),
        );

        await _authService.updateChallengeProgress(
          _user!['id'],
          'roulette',
          'bet_amount',
          betAmount.toDouble(),
        );
        
        setState(() {
          _user!['balance'] = newBalance;
        });
        
        _showResultDialog(
          context,
          "Поздравляем!",
          "Выпало число: $result\nВы выиграли ${totalPayout.toStringAsFixed(0)} монет!"
        );
      } else {
        final newBalance = _user!['balance'] - betAmount;
        await _dbHelper.updateUserBalance(_user!['id'], newBalance);
        await _dbHelper.addGameHistory({
          'user_id': _user!['id'],
          'game_type': 'roulette',
          'bet_amount': betAmount.toDouble(),
          'win_amount': 0.0,
          'result': 'lose',
          'created_at': DateTime.now().toIso8601String(),
        });
        
        // Обновляем прогресс испытаний
        await _authService.updateChallengeProgress(
          _user!['id'],
          'roulette',
          'play_games',
          1.0,
        );

        await _authService.updateChallengeProgress(
          _user!['id'],
          'roulette',
          'bet_amount',
          betAmount.toDouble(),
        );
        
        setState(() {
          _user!['balance'] = newBalance;
        });
        
        _showResultDialog(
          context,
          "Удачи в следующий раз!",
          "Выпало число: $result\nВы проиграли ${betAmount.toStringAsFixed(0)} монет"
        );
      }
    }

    setState(() {
      selectedBets.clear();
      betAmountController.clear();
      startBettingPhase();
    });
  }

  void _showResultDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
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

  void startBettingPhase() {
    setState(() {
      isLocked = false;
      timeLeft = 30;
    });

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (timeLeft > 0) {
          timeLeft--;
        } else {
          isLocked = true;
          timer.cancel();
          selected.add(Fortune.randomInt(0, items.length));
        }
      });
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

    final screenWidth = MediaQuery.of(context).size.width;
    final wheelSize = screenWidth * 0.8;
    final adjustedWheelSize = screenWidth > 650 ? 520.0 : wheelSize;
    final gridItemSize = screenWidth * 0.2;
    final coinSize = screenWidth > 650 ? 45.7 : 30.7;
    final fontSize = screenWidth > 650 ? 24.0 : 24.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Рулетка'),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: adjustedWheelSize,
                        width: adjustedWheelSize,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              height: adjustedWheelSize * 0.93,
                              child: FortuneWheel(
                                selected: selected.stream,
                                animateFirst: false,
                                items: [
                                  for (int i = 0; i < items.length; i++) ...<FortuneItem>{
                                    FortuneItem(
                                      child: Transform.rotate(
                                        angle: 1.57,
                                        child: Transform.translate(
                                          offset: Offset(0, -(adjustedWheelSize * 0.1)),
                                          child: Text(
                                            items[i].toString(),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      style: FortuneItemStyle(
                                        borderColor: Colors.white,
                                        color: items[i] == 0
                                            ? Colors.green
                                            : i.isEven
                                                ? Colors.black
                                                : Colors.red,
                                        borderWidth: 2,
                                      ),
                                    ),
                                  },
                                ],
                                indicators: const [],
                                onAnimationEnd: () {
                                  checkBetOutcome(items[selected.value]);
                                },
                              ),
                            ),
                            Positioned(
                              top: 0,
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Align(
                                alignment: Alignment.center,
                                child: Image.asset(
                                  'images/bordb.png',
                                  width: adjustedWheelSize,
                                  height: adjustedWheelSize,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (!isLocked)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            border: Border.all(
                              color: Colors.white,
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(12.0),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                offset: Offset(0, 4),
                                blurRadius: 10.0,
                              ),
                            ],
                          ),
                          child: Text(
                            'Время для ставок: $timeLeft секунд',
                            style: TextStyle(
                              fontSize: screenWidth * 0.05,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: gridItemSize * 3,
                        width: screenWidth * 0.9,
                        child: GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: screenWidth * 0.04,
                            mainAxisSpacing: screenWidth * 0.04,
                            childAspectRatio: 1,
                          ),
                          itemCount: 8,
                          itemBuilder: (context, index) {
                            String label;
                            String multiplier;
                            switch (index) {
                              case 0:
                                label = '0';
                                multiplier = 'x36';
                                break;
                              case 1:
                                label = '1-12';
                                multiplier = 'x3';
                                break;
                              case 2:
                                label = '13-24';
                                multiplier = 'x3';
                                break;
                              case 3:
                                label = '25-36';
                                multiplier = 'x3';
                                break;
                              case 4:
                                label = 'Red';
                                multiplier = 'x2';
                                break;
                              case 5:
                                label = 'Black';
                                multiplier = 'x2';
                                break;
                              case 6:
                                label = 'Odd';
                                multiplier = 'x2';
                                break;
                              case 7:
                                label = 'Even';
                                multiplier = 'x2';
                                break;
                              default:
                                label = '';
                                multiplier = '';
                            }

                            return GestureDetector(
                              onTap: isLocked
                                  ? null
                                  : () {
                                      int betAmount = int.tryParse(betAmountController.text) ?? 0;
                                      if (betAmount <= 0) {
                                        Get.snackbar(
                                          'Ошибка',
                                          'Пожалуйста, введите сумму ставки',
                                          backgroundColor: Colors.red,
                                          colorText: Colors.white,
                                        );
                                        return;
                                      } else if (betAmount > _user!['balance']) {
                                        Get.snackbar(
                                          'Ошибка',
                                          'Недостаточно средств',
                                          backgroundColor: Colors.red,
                                          colorText: Colors.white,
                                        );
                                        return;
                                      }

                                      setState(() {
                                        if (selectedBets.contains(label)) {
                                          selectedBets.remove(label);
                                        } else {
                                          if (label == '0') {
                                            selectedBets.clear();
                                            selectedBets.add(label);
                                          } else {
                                            if (selectedBets.contains('0')) {
                                              Get.snackbar(
                                                'Ошибка',
                                                'Нельзя выбрать другие варианты при ставке на 0',
                                                backgroundColor: Colors.red,
                                                colorText: Colors.white,
                                              );
                                            } else {
                                              if (label == 'Odd' && selectedBets.contains('Even')) {
                                                selectedBets.remove('Even');
                                              } else if (label == 'Even' && selectedBets.contains('Odd')) {
                                                selectedBets.remove('Odd');
                                              } else if (label == 'Red' && selectedBets.contains('Black')) {
                                                selectedBets.remove('Black');
                                              } else if (label == 'Black' && selectedBets.contains('Red')) {
                                                selectedBets.remove('Red');
                                              }

                                              if (label == '1-12' || label == '13-24' || label == '25-36') {
                                                List<String> selectedRangeBets = selectedBets.where((bet) => bet == '1-12' || bet == '13-24' || bet == '25-36').toList();
                                                if (selectedRangeBets.length == 2) {
                                                  selectedBets.remove(selectedRangeBets[0]);
                                                }
                                              }

                                              selectedBets.add(label);
                                            }
                                          }
                                        }
                                      });
                                    },
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: selectedBets.contains(label)
                                      ? LinearGradient(
                                          colors: [
                                            Colors.blue[900]!,
                                            Colors.purple[900]!,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0.1),
                                            Colors.white.withOpacity(0.2),
                                          ],
                                        ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selectedBets.contains(label) ? Colors.white : Colors.white.withOpacity(0.3),
                                    width: 2,
                                  ),
                                  boxShadow: selectedBets.contains(label)
                                      ? [
                                          BoxShadow(
                                            color: Colors.blue[900]!.withOpacity(0.5),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.05,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      multiplier,
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.04,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                        child: TextField(
                          controller: betAmountController,
                          keyboardType: TextInputType.number,
                          enabled: !isLocked,
                          style: TextStyle(
                            fontSize: screenWidth * 0.05,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Image.asset(
                                'images/coin.png',
                                width: screenWidth * 0.08,
                                height: screenWidth * 0.08,
                                color: Colors.white,
                              ),
                            ),
                            hintText: 'Введите сумму ставки',
                            hintStyle: TextStyle(
                              fontSize: screenWidth * 0.045,
                              color: Colors.white.withOpacity(0.6),
                              fontWeight: FontWeight.w400,
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
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
} 