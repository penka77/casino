import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../auth/auth_service.dart';
import '../../../core/database/database_helper.dart';
import '../../auth/login_screen.dart';
import 'dart:math';
import 'dart:async';

class PokerScreen extends StatefulWidget {
  const PokerScreen({Key? key}) : super(key: key);

  @override
  _PokerScreenState createState() => _PokerScreenState();
}

class _PokerScreenState extends State<PokerScreen> {
  final _authService = AuthService();
  final _dbHelper = DatabaseHelper.instance;
  Map<String, dynamic>? _user;
  List<String> _deck = [];
  List<String> _playerHand = [];
  List<String> _botHand = [];
  List<String> _communityCards = [];
  double _currentBet = 0;
  double _pot = 0;
  double _minBet = 10;
  bool _isGameStarted = false;
  bool _isPlayerTurn = true;
  bool _isBotThinking = false;
  String _gameStatus = '';
  Timer? _botTimer;
  int _currentRound = 0; // 0: Pre-flop, 1: Flop, 2: Turn, 3: River
  double _playerBet = 0;
  double _botBet = 0;

  // Poker hand rankings
  final Map<String, int> _cardValues = {
    '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8, '9': 9, '10': 10,
    'В': 11, 'Д': 12, 'К': 13, 'Т': 14
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initializeDeck();
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }

  void _initializeDeck() {
    final suits = ['♠', '♥', '♦', '♣'];
    final values = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'В', 'Д', 'К', 'Т'];
    _deck = [];
    
    for (var suit in suits) {
      for (var value in values) {
        _deck.add('$value$suit');
      }
    }
    _deck.shuffle();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        setState(() {
          _user = user;
        });
      } else {
        Get.offAll(() => const LoginScreen());
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

  void _startNewGame() {
    if (_user == null || _user!['balance'] < _minBet) {
      Get.snackbar(
        'Ошибка',
        'Недостаточно средств для начала игры',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _isGameStarted = true;
      _isPlayerTurn = true;
      _currentBet = 0;
      _pot = 0;
      _playerHand = [];
      _botHand = [];
      _communityCards = [];
      _gameStatus = '';
      _currentRound = 0;
      _playerBet = 0;
      _botBet = 0;
    });

    _initializeDeck();
    _dealInitialCards();
    _placeInitialBets();
  }

  void _placeInitialBets() {
    setState(() {
      _playerBet = _minBet;
      _botBet = _minBet;
      _currentBet = _minBet;
      _pot = _minBet * 2;
      _user!['balance'] -= _minBet;
    });
  }

  void _dealInitialCards() {
    for (int i = 0; i < 2; i++) {
      _playerHand.add(_deck.removeLast());
      _botHand.add(_deck.removeLast());
    }
  }

  void _dealCommunityCards() {
    if (_currentRound == 1) { // Flop
      for (int i = 0; i < 3; i++) {
        _communityCards.add(_deck.removeLast());
      }
    } else if (_currentRound == 2 || _currentRound == 3) { // Turn or River
      _communityCards.add(_deck.removeLast());
    }
  }

  void _placeBet(double amount) {
    if (_user == null || _user!['balance'] < amount) {
      Get.snackbar(
        'Ошибка',
        'Недостаточно средств',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _user!['balance'] -= amount;
      _playerBet += amount;
      _currentBet = _playerBet;
      _pot += amount;
      _isPlayerTurn = false;
    });

    _botAction();
  }

  void _fold() {
    setState(() {
      _isGameStarted = false;
      _gameStatus = 'Вы сбросили карты';
      _endRound(false);
    });
  }

  void _check() {
    if (_currentBet > _playerBet) {
      Get.snackbar(
        'Ошибка',
        'Нельзя проверить, когда есть ставка',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _isPlayerTurn = false;
    });
    _botAction();
  }

  void _call() {
    double callAmount = _currentBet - _playerBet;
    if (callAmount > 0) {
      setState(() {
        _user!['balance'] -= callAmount;
        _playerBet += callAmount;
        _pot += callAmount;
      });
    }
    
    // После колла сразу открываем следующую карту
    _nextRound();
  }

  void _botAction() {
    setState(() {
      _isBotThinking = true;
    });

    _botTimer?.cancel();
    _botTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;

      // Если ставки равны, дилер проверяет
      if (_currentBet == _botBet) {
        setState(() {
          _isBotThinking = false;
          _gameStatus = 'Дилер проверяет';
          _nextRound();
        });
        return;
      }

      final random = Random();
      final handStrength = _evaluateHandStrength(_botHand, _communityCards);
      final action = _determineBotAction(handStrength);

      setState(() {
        _isBotThinking = false;
        switch (action) {
          case 'fold':
            _gameStatus = 'Дилер сбрасывает карты';
            _endRound(true);
            break;
          case 'check':
            _gameStatus = 'Дилер проверяет';
            _nextRound();
            break;
          case 'call':
            double callAmount = _currentBet - _botBet;
            _botBet += callAmount;
            _pot += callAmount;
            _gameStatus = 'Дилер уравнивает ставку: ${callAmount.toStringAsFixed(0)} монет';
            _nextRound();
            break;
          case 'raise':
            double raiseAmount = _currentBet * 2;
            _botBet += raiseAmount;
            _pot += raiseAmount;
            _currentBet = raiseAmount;
            _gameStatus = 'Дилер повышает ставку: ${raiseAmount.toStringAsFixed(0)} монет';
            _isPlayerTurn = true;
            break;
        }
      });
    });
  }

  String _determineBotAction(double handStrength) {
    final random = Random();
    
    // Более логичные пороги для принятия решений
    if (handStrength < 0.4) {
      // Слабая рука
      if (_currentBet > _minBet * 2) {
        return 'fold';
      }
      return random.nextDouble() < 0.8 ? 'fold' : 'call';
    } else if (handStrength < 0.7) {
      // Средняя рука
      if (_currentBet > _minBet * 3) {
        return random.nextDouble() < 0.7 ? 'fold' : 'call';
      }
      return random.nextDouble() < 0.4 ? 'raise' : 'call';
    } else {
      // Сильная рука
      if (_currentBet > _minBet * 4) {
        return random.nextDouble() < 0.3 ? 'fold' : 'call';
      }
      return random.nextDouble() < 0.7 ? 'raise' : 'call';
    }
  }

  double _evaluateHandStrength(List<String> hand, List<String> community) {
    // Оцениваем текущую силу руки
    List<String> allCards = [...hand, ...community];
    int currentScore = _evaluateHand(allCards);
    
    // Если у нас уже есть сильная комбинация
    if (currentScore >= 5000) return 0.9;
    if (currentScore >= 3000) return 0.8;
    if (currentScore >= 2000) return 0.7;
    
    // Оцениваем потенциал руки
    double potential = 0.0;
    
    // Проверяем потенциал флеша
    Map<String, int> suitCount = {};
    for (var card in allCards) {
      String suit = card.substring(card.length - 1);
      suitCount[suit] = (suitCount[suit] ?? 0) + 1;
    }
    int maxSuitCount = suitCount.values.reduce(max);
    if (maxSuitCount >= 4) potential += 0.3;
    if (maxSuitCount >= 3) potential += 0.2;
    
    // Проверяем потенциал стрита
    List<int> values = allCards.map((card) => 
      _cardValues[card.substring(0, card.length - 1)] ?? 0).toList();
    values.sort();
    values = values.toSet().toList();
    
    int consecutiveCount = 1;
    int maxConsecutive = 1;
    for (int i = 1; i < values.length; i++) {
      if (values[i] - values[i-1] == 1) {
        consecutiveCount++;
        maxConsecutive = max(maxConsecutive, consecutiveCount);
      } else {
        consecutiveCount = 1;
      }
    }
    if (maxConsecutive >= 4) potential += 0.3;
    if (maxConsecutive >= 3) potential += 0.2;
    
    // Проверяем потенциал пары/сета
    Map<String, int> valueCount = {};
    for (var card in allCards) {
      String value = card.substring(0, card.length - 1);
      valueCount[value] = (valueCount[value] ?? 0) + 1;
    }
    int maxValueCount = valueCount.values.reduce(max);
    if (maxValueCount >= 3) potential += 0.3;
    if (maxValueCount >= 2) potential += 0.2;
    
    // Учитываем старшие карты
    int highCard = values.reduce(max);
    potential += (highCard / 14) * 0.1;
    
    return min(0.9, (currentScore / 8000) * 0.5 + potential * 0.5);
  }

  int _evaluateHand(List<String> cards) {
    // Сортируем карты по убыванию
    cards.sort((a, b) {
      int valueA = _cardValues[a.substring(0, a.length - 1)] ?? 0;
      int valueB = _cardValues[b.substring(0, b.length - 1)] ?? 0;
      return valueB.compareTo(valueA);
    });

    // Получаем все возможные комбинации из 5 карт
    List<List<String>> fiveCardCombinations = _getFiveCardCombinations(cards);
    
    // Находим лучшую комбинацию
    int bestScore = 0;
    for (var combination in fiveCardCombinations) {
      int score = _evaluateFiveCardHand(combination);
      bestScore = max(bestScore, score);
    }
    
    return bestScore;
  }

  List<List<String>> _getFiveCardCombinations(List<String> cards) {
    List<List<String>> combinations = [];
    void generateCombinations(int start, List<String> current) {
      if (current.length == 5) {
        combinations.add(List.from(current));
        return;
      }
      for (int i = start; i < cards.length; i++) {
        current.add(cards[i]);
        generateCombinations(i + 1, current);
        current.removeLast();
      }
    }
    generateCombinations(0, []);
    return combinations;
  }

  int _evaluateFiveCardHand(List<String> cards) {
    if (_hasStraightFlush(cards)) {
      // Добавляем значение старшей карты для различения стрит-флешей
      return 8000 + _getHighCard(cards);
    }
    if (_hasFourOfAKind(cards)) {
      // Добавляем значение карты, которая составляет каре
      Map<String, int> valueCount = {};
      for (var card in cards) {
        String value = card.substring(0, card.length - 1);
        valueCount[value] = (valueCount[value] ?? 0) + 1;
      }
      String fourCard = valueCount.entries.firstWhere((e) => e.value == 4).key;
      return 7000 + (_cardValues[fourCard] ?? 0);
    }
    if (_hasFullHouse(cards)) {
      // Добавляем значение тройки и пары
      Map<String, int> valueCount = {};
      for (var card in cards) {
        String value = card.substring(0, card.length - 1);
        valueCount[value] = (valueCount[value] ?? 0) + 1;
      }
      String threeCard = valueCount.entries.firstWhere((e) => e.value == 3).key;
      String pairCard = valueCount.entries.firstWhere((e) => e.value == 2).key;
      return 6000 + (_cardValues[threeCard] ?? 0) * 14 + (_cardValues[pairCard] ?? 0);
    }
    if (_hasFlush(cards)) {
      // Добавляем значения всех карт для различения флешей
      List<int> values = cards.map((card) => 
        _cardValues[card.substring(0, card.length - 1)] ?? 0).toList();
      values.sort((a, b) => b.compareTo(a));
      return 5000 + values[0] * 14 * 14 * 14 * 14 +
             values[1] * 14 * 14 * 14 +
             values[2] * 14 * 14 +
             values[3] * 14 +
             values[4];
    }
    if (_hasStraight(cards)) {
      // Добавляем значение старшей карты для различения стритов
      return 4000 + _getHighCard(cards);
    }
    if (_hasThreeOfAKind(cards)) {
      // Добавляем значение тройки и кикеров
      Map<String, int> valueCount = {};
      for (var card in cards) {
        String value = card.substring(0, card.length - 1);
        valueCount[value] = (valueCount[value] ?? 0) + 1;
      }
      String threeCard = valueCount.entries.firstWhere((e) => e.value == 3).key;
      List<int> kickers = valueCount.entries
          .where((e) => e.value == 1)
          .map((e) => _cardValues[e.key] ?? 0)
          .toList()
        ..sort((a, b) => b.compareTo(a));
      return 3000 + (_cardValues[threeCard] ?? 0) * 14 * 14 +
             kickers[0] * 14 +
             kickers[1];
    }
    if (_hasTwoPair(cards)) {
      // Добавляем значения пар и кикера
      Map<String, int> valueCount = {};
      for (var card in cards) {
        String value = card.substring(0, card.length - 1);
        valueCount[value] = (valueCount[value] ?? 0) + 1;
      }
      List<String> pairs = valueCount.entries
          .where((e) => e.value == 2)
          .map((e) => e.key)
          .toList()
        ..sort((a, b) => (_cardValues[b] ?? 0).compareTo(_cardValues[a] ?? 0));
      String kicker = valueCount.entries
          .firstWhere((e) => e.value == 1)
          .key;
      return 2000 + (_cardValues[pairs[0]] ?? 0) * 14 * 14 +
             (_cardValues[pairs[1]] ?? 0) * 14 +
             (_cardValues[kicker] ?? 0);
    }
    if (_hasOnePair(cards)) {
      // Добавляем значение пары и кикеров
      Map<String, int> valueCount = {};
      for (var card in cards) {
        String value = card.substring(0, card.length - 1);
        valueCount[value] = (valueCount[value] ?? 0) + 1;
      }
      String pair = valueCount.entries.firstWhere((e) => e.value == 2).key;
      List<int> kickers = valueCount.entries
          .where((e) => e.value == 1)
          .map((e) => _cardValues[e.key] ?? 0)
          .toList()
        ..sort((a, b) => b.compareTo(a));
      return 1000 + (_cardValues[pair] ?? 0) * 14 * 14 * 14 +
             kickers[0] * 14 * 14 +
             kickers[1] * 14 +
             kickers[2];
    }
    // Старшая карта
    List<int> values = cards.map((card) => 
      _cardValues[card.substring(0, card.length - 1)] ?? 0).toList();
    values.sort((a, b) => b.compareTo(a));
    return values[0] * 14 * 14 * 14 * 14 +
           values[1] * 14 * 14 * 14 +
           values[2] * 14 * 14 +
           values[3] * 14 +
           values[4];
  }

  void _nextRound() {
    if (_currentRound < 3) {
      setState(() {
        _currentRound++;
        _dealCommunityCards();
        _isPlayerTurn = true;
        _currentBet = 0;
        _playerBet = 0;
        _botBet = 0;
      });
    } else {
      _showdown();
    }
  }

  void _showdown() {
    final playerScore = _evaluateHand([..._playerHand, ..._communityCards]);
    final botScore = _evaluateHand([..._botHand, ..._communityCards]);

    if (playerScore > botScore) {
      setState(() {
        _user!['balance'] += _pot;
        _gameStatus = 'Вы выиграли ${_pot.toStringAsFixed(0)} монет!';
      });
      _endRound(true);
    } else if (botScore > playerScore) {
      setState(() {
        _gameStatus = 'Дилер выиграл ${_pot.toStringAsFixed(0)} монет';
      });
      _endRound(false);
    } else {
      setState(() {
        _user!['balance'] += _pot / 2;
        _gameStatus = 'Ничья! Возврат ${(_pot / 2).toStringAsFixed(0)} монет';
      });
      _endRound(false);
    }
  }

  bool _hasStraightFlush(List<String> cards) {
    return _hasFlush(cards) && _hasStraight(cards);
  }

  bool _hasFourOfAKind(List<String> cards) {
    Map<String, int> valueCount = {};
    for (var card in cards) {
      String value = card.substring(0, card.length - 1);
      valueCount[value] = (valueCount[value] ?? 0) + 1;
    }
    return valueCount.values.any((count) => count >= 4);
  }

  bool _hasFullHouse(List<String> cards) {
    Map<String, int> valueCount = {};
    for (var card in cards) {
      String value = card.substring(0, card.length - 1);
      valueCount[value] = (valueCount[value] ?? 0) + 1;
    }
    bool hasThree = false;
    bool hasPair = false;
    for (var count in valueCount.values) {
      if (count >= 3) hasThree = true;
      if (count >= 2) hasPair = true;
    }
    return hasThree && hasPair;
  }

  bool _hasFlush(List<String> cards) {
    Map<String, int> suitCount = {};
    for (var card in cards) {
      String suit = card.substring(card.length - 1);
      suitCount[suit] = (suitCount[suit] ?? 0) + 1;
    }
    return suitCount.values.any((count) => count >= 5);
  }

  bool _hasStraight(List<String> cards) {
    List<int> values = cards.map((card) => 
      _cardValues[card.substring(0, card.length - 1)] ?? 0).toList();
    values.sort();
    values = values.toSet().toList();
    
    if (values.length < 5) return false;
    
    for (int i = 0; i <= values.length - 5; i++) {
      if (values[i + 4] - values[i] == 4) return true;
    }
    
    if (values.contains(14)) {
      values.add(1);
      values.sort();
      for (int i = 0; i <= values.length - 5; i++) {
        if (values[i + 4] - values[i] == 4) return true;
      }
    }
    
    return false;
  }

  bool _hasThreeOfAKind(List<String> cards) {
    Map<String, int> valueCount = {};
    for (var card in cards) {
      String value = card.substring(0, card.length - 1);
      valueCount[value] = (valueCount[value] ?? 0) + 1;
    }
    return valueCount.values.any((count) => count >= 3);
  }

  bool _hasTwoPair(List<String> cards) {
    Map<String, int> valueCount = {};
    for (var card in cards) {
      String value = card.substring(0, card.length - 1);
      valueCount[value] = (valueCount[value] ?? 0) + 1;
    }
    int pairCount = 0;
    for (var count in valueCount.values) {
      if (count >= 2) pairCount++;
    }
    return pairCount >= 2;
  }

  bool _hasOnePair(List<String> cards) {
    Map<String, int> valueCount = {};
    for (var card in cards) {
      String value = card.substring(0, card.length - 1);
      valueCount[value] = (valueCount[value] ?? 0) + 1;
    }
    return valueCount.values.any((count) => count >= 2);
  }

  int _getHighCard(List<String> cards) {
    return cards.map((card) => 
      _cardValues[card.substring(0, card.length - 1)] ?? 0).reduce(max);
  }

  void _endRound(bool playerWon) async {
    if (_user != null) {
      // Обновляем баланс пользователя
      if (playerWon) {
        await _dbHelper.updateUserBalance(_user!['id'], _user!['balance']);
      }

      // Сохраняем историю игры
      await _dbHelper.addGameHistory({
        'user_id': _user!['id'],
        'game_type': 'poker',
        'bet_amount': _minBet.toDouble(),
        'win_amount': playerWon ? _pot.toDouble() : 0.0,
        'result': playerWon ? 'win' : 'lose',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Обновляем прогресс испытаний
      await _authService.updateChallengeProgress(
        _user!['id'],
        'poker',
        'play_games',
        1.0,
      );

      if (playerWon) {
        await _authService.updateChallengeProgress(
          _user!['id'],
          'poker',
          'win',
          1.0,
        );

        await _authService.updateChallengeProgress(
          _user!['id'],
          'poker',
          'win_amount',
          _pot.toDouble(),
        );
      }

      await _authService.updateChallengeProgress(
        _user!['id'],
        'poker',
        'bet_amount',
        _minBet.toDouble(),
      );
    }

    setState(() {
      _isGameStarted = false;
      _playerHand = [];
      _botHand = [];
      _communityCards = [];
      _currentRound = 0;
      _pot = 0;
      _currentBet = 0;
      _playerBet = 0;
      _botBet = 0;
    });
  }

  String _getHandDescription(List<String> cards) {
    if (_hasStraightFlush(cards)) return 'Стрит-флеш';
    if (_hasFourOfAKind(cards)) return 'Каре';
    if (_hasFullHouse(cards)) return 'Фулл-хаус';
    if (_hasFlush(cards)) return 'Флеш';
    if (_hasStraight(cards)) return 'Стрит';
    if (_hasThreeOfAKind(cards)) return 'Тройка';
    if (_hasTwoPair(cards)) return 'Две пары';
    if (_hasOnePair(cards)) return 'Пара';
    return 'Старшая карта';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Покер'),
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
              _buildHeader(),
              if (_isBotThinking)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.amber,
                  child: const Text(
                    'Дилер думает...',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (_gameStatus.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.white.withOpacity(0.2),
                  child: Text(
                    _gameStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildCommunityCards(),
                      const SizedBox(height: 32),
                      _buildBotHand(),
                      const SizedBox(height: 32),
                      _buildPlayerHand(),
                      const SizedBox(height: 32),
                      _buildGameControls(),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Баланс: ${_user?['balance']?.toStringAsFixed(0) ?? '0'} монет',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Банк: ${_pot.toStringAsFixed(0)} монет',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityCards() {
    return Column(
      children: [
        const Text(
          'Карты на столе',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 100,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(5, (index) {
                if (index < _communityCards.length) {
                  return _buildCard(_communityCards[index]);
                }
                return _buildEmptyCard();
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBotHand() {
    return Column(
      children: [
        const Text(
          'Дилер',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ставка: ${_botBet.toStringAsFixed(0)} монет',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 100,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(2, (index) {
                if (index < _botHand.length) {
                  return _buildCard(_botHand[index]);
                }
                return _buildEmptyCard();
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerHand() {
    return Column(
      children: [
        const Text(
          'Ваши карты',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ставка: ${_playerBet.toStringAsFixed(0)} монет',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 100,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(2, (index) {
                if (index < _playerHand.length) {
                  return _buildCard(_playerHand[index]);
                }
                return _buildEmptyCard();
              }),
            ],
          ),
        ),
        if (_isGameStarted && _playerHand.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Комбинация: ${_getHandDescription([..._playerHand, ..._communityCards])}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCard(String card) {
    final isRed = card.contains('♥') || card.contains('♦');
    return Container(
      width: 60,
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          card,
          style: TextStyle(
            color: isRed ? Colors.red : Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      width: 60,
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white30),
      ),
    );
  }

  Widget _buildGameControls() {
    if (!_isGameStarted) {
      return Column(
        children: [
          const Text(
            'Минимальная ставка: 10₽',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _startNewGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue[900],
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Начать игру',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }

    if (!_isPlayerTurn) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton('Сбросить', Colors.red, _fold),
            _buildActionButton('Проверить', Colors.blue, _check),
            _buildActionButton('Колл', Colors.green, _call),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton('+10₽', Colors.amber, () => _placeBet(10)),
            _buildActionButton('+50₽', Colors.orange, () => _placeBet(50)),
            _buildActionButton('+100₽', Colors.purple, () => _placeBet(100)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
} 