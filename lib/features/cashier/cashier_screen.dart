import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../auth/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/payment_config.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({Key? key}) : super(key: key);

  @override
  _CashierScreenState createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  final _authService = AuthService();
  final _amountController = TextEditingController();
  bool _isLoading = false;
  double _coins = 0;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_updateCoins);
  }

  void _updateCoins() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    setState(() {
      _coins = amount * PaymentConfig.conversionRate;
    });
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateCoins);
    _amountController.dispose();
    super.dispose();
  }

  Future<bool?> _showDemoPaymentDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Демо-оплата'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Сумма к оплате: ${_amountController.text} ₽'),
              const SizedBox(height: 8),
              Text('Вы получите: ${_coins.toStringAsFixed(0)} монет'),
              const SizedBox(height: 16),
              const Text(
                'Тестовые карты:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('1111 1111 1111 1026 - Успешная оплата'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Оплатить'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateBalance() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        final currentBalance = user['balance'] as double;
        final newBalance = currentBalance + _coins;
        
        print('Updating balance: $currentBalance -> $newBalance'); // Debug log
        
        await _authService.updateUserBalance(newBalance);
        
        // Обновляем данные пользователя после пополнения
        final updatedUser = await _authService.getCurrentUser();
        print('Updated user balance: ${updatedUser?['balance']}'); // Debug log
        
        Get.snackbar(
          'Успех',
          'Баланс успешно пополнен на ${_coins.toStringAsFixed(0)} монет',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        
        // Возвращаемся на предыдущий экран и обновляем его
        Get.back(result: true);
      } else {
        Get.snackbar(
          'Ошибка',
          'Пользователь не найден',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('Error updating balance: $e');
      Get.snackbar(
        'Ошибка',
        'Не удалось обновить баланс: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _processPayment() async {
    if (_amountController.text.isEmpty) {
      Get.snackbar(
        'Ошибка',
        'Введите сумму пополнения',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      Get.snackbar(
        'Ошибка',
        'Введите корректную сумму',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bool? result = await _showDemoPaymentDialog();
      
      if (result == true) {
        await _updateBalance();
      }
    } catch (e) {
      print('Payment error: $e');
      Get.snackbar(
        'Ошибка',
        'Не удалось пополнить баланс',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Пополнение баланса'),
        backgroundColor: Colors.blue[900],
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Пополнение баланса',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '1 рубль = ${PaymentConfig.conversionRate} монет',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Сумма в рублях',
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixText: '₽ ',
                          prefixStyle: const TextStyle(color: Colors.white),
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
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'images/coin.png',
                              width: 32,
                              height: 32,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Вы получите: ${_coins.toStringAsFixed(0)} монет',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _processPayment,
                    icon: const Icon(Icons.credit_card),
                    label: const Text(
                      'Оплатить картой',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: CircularProgressIndicator(),
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