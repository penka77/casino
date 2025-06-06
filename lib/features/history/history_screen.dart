import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/database/database_helper.dart';
import 'package:intl/intl.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _dbHelper = DatabaseHelper.instance;
  final _authService = AuthService();
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.getCurrentUser();
      print('Current user: $user');
      
      if (user != null) {
        final history = await _dbHelper.getUserGameHistory(user['id']);
        print('Loaded history: $history');
        
        if (mounted) {
          setState(() {
            _user = user;
            _history = history;
            _isLoading = false;
          });
        }
      } else {
        print('User not found');
        if (mounted) {
          Get.snackbar(
            'Ошибка',
            'Пользователь не найден',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          Get.offAll(() => const LoginScreen());
        }
      }
    } catch (e) {
      print('Error loading history: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        Get.snackbar(
          'Ошибка',
          'Не удалось загрузить историю игр',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  String _getGameTypeIcon(String gameType) {
    switch (gameType.toLowerCase()) {
      case 'roulette':
        return '🎲';
      case 'poker':
        return '🃏';
      case 'coin_flip':
        return '🪙';
      case 'dice':
        return '🎲';
      default:
        return '🎮';
    }
  }

  String _getGameTypeName(String gameType) {
    switch (gameType.toLowerCase()) {
      case 'roulette':
        return 'Рулетка';
      case 'poker':
        return 'Покер';
      case 'coin_flip':
        return 'Орел и Решка';
      case 'dice':
        return 'Кости';
      default:
        return gameType;
    }
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final formatter = DateFormat('dd.MM.yyyy HH:mm');
      return formatter.format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История игр'),
        backgroundColor: Colors.blue[900],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
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
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : Column(
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
                      child: _history.isEmpty
                          ? const Center(
                              child: Text(
                                'История игр пуста',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadData,
                              child: ListView.builder(
                                itemCount: _history.length,
                                itemBuilder: (context, index) {
                                  try {
                                    final game = _history[index];
                                    final isWin = game['result'] == 'win';
                                    final gameType = game['game_type'] as String;
                                    final betAmount = (game['bet_amount'] as num).toDouble();
                                    final winAmount = (game['win_amount'] as num).toDouble();

                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      color: Colors.white.withOpacity(0.1),
                                      child: ListTile(
                                        leading: Text(
                                          _getGameTypeIcon(gameType),
                                          style: const TextStyle(fontSize: 24),
                                        ),
                                        title: Text(
                                          _getGameTypeName(gameType),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(
                                          _formatDateTime(game['created_at']),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        trailing: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Ставка: ${betAmount.toStringAsFixed(2)}₽',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              isWin
                                                  ? '+${winAmount.toStringAsFixed(2)}₽'
                                                  : '-${betAmount.toStringAsFixed(2)}₽',
                                              style: TextStyle(
                                                color: isWin ? Colors.green : Colors.red,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    print('Error building history item: $e');
                                    return const SizedBox.shrink();
                                  }
                                },
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