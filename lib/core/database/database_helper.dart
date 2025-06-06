import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../features/auth/auth_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static dynamic _database;
  static const String _dbName = 'casino.db';
  static const int _dbVersion = 3; // Increased version for new tables

  factory DatabaseHelper() => _instance;

  static DatabaseHelper get instance => _instance;

  DatabaseHelper._internal();

  Future<dynamic> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<dynamic> _initDatabase() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      // Инициализируем пустые списки для истории игр и пользователей, если они не существуют
      if (!prefs.containsKey('game_history')) {
        await prefs.setString('game_history', '[]');
      }
      if (!prefs.containsKey('users')) {
        await prefs.setString('users', '[]');
      }
      // Проверяем и инициализируем испытания
      final challengesJson = prefs.getString('challenges');
      if (challengesJson == null || List<Map<String, dynamic>>.from(json.decode(challengesJson)).isEmpty) {
        await _insertDefaultChallengesForSharedPreferences(prefs);
      }
      return prefs;
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        balance REAL DEFAULT 0.0,
        avatar_url TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE game_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        game_type TEXT NOT NULL,
        bet_amount REAL NOT NULL,
        win_amount REAL NOT NULL,
        result TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE challenges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        type TEXT NOT NULL, -- 'daily', 'weekly', 'long_term'
        requirement_type TEXT NOT NULL, -- 'wins', 'games_played', 'total_bet', 'total_win'
        requirement_value INTEGER NOT NULL,
        reward_type TEXT NOT NULL, -- 'coins', 'bonus'
        reward_value INTEGER NOT NULL,
        is_active BOOLEAN DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE user_challenges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        challenge_id INTEGER NOT NULL,
        progress INTEGER DEFAULT 0,
        is_completed BOOLEAN DEFAULT 0,
        completed_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id),
        FOREIGN KEY (challenge_id) REFERENCES challenges (id)
      )
    ''');

    // Insert default challenges
    await _insertDefaultChallenges(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add challenges and user_challenges tables
      await db.execute('''
        CREATE TABLE challenges (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          description TEXT NOT NULL,
          type TEXT NOT NULL,
          requirement_type TEXT NOT NULL,
          requirement_value INTEGER NOT NULL,
          reward_type TEXT NOT NULL,
          reward_value INTEGER NOT NULL,
          is_active BOOLEAN DEFAULT 1,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await db.execute('''
        CREATE TABLE user_challenges (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          challenge_id INTEGER NOT NULL,
          progress INTEGER DEFAULT 0,
          is_completed BOOLEAN DEFAULT 0,
          completed_at TIMESTAMP,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (user_id) REFERENCES users (id),
          FOREIGN KEY (challenge_id) REFERENCES challenges (id)
        )
      ''');

      // Insert default challenges
      await _insertDefaultChallenges(db);
    }
  }

  Future<void> _insertDefaultChallenges(Database db) async {
    // Daily Challenges
    await db.insert('challenges', {
      'title': 'Первая победа дня',
      'description': 'Выиграйте одну игру',
      'type': 'daily',
      'requirement_type': 'wins',
      'requirement_value': 1,
      'reward_type': 'coins',
      'reward_value': 50,
      'is_active': 1,
    });

    await db.insert('challenges', {
      'title': 'Азартный игрок',
      'description': 'Сыграйте 5 игр',
      'type': 'daily',
      'requirement_type': 'games_played',
      'requirement_value': 5,
      'reward_type': 'coins',
      'reward_value': 100,
      'is_active': 1,
    });

    await db.insert('challenges', {
      'title': 'Большая ставка',
      'description': 'Сделайте ставку на 100 монет',
      'type': 'daily',
      'requirement_type': 'total_bet',
      'requirement_value': 100,
      'reward_type': 'coins',
      'reward_value': 150,
      'is_active': 1,
    });

    // Weekly Challenges
    await db.insert('challenges', {
      'title': 'Недельный победитель',
      'description': 'Выиграйте 10 игр за неделю',
      'type': 'weekly',
      'requirement_type': 'wins',
      'requirement_value': 10,
      'reward_type': 'coins',
      'reward_value': 500,
      'is_active': 1,
    });

    await db.insert('challenges', {
      'title': 'Недельный игрок',
      'description': 'Сыграйте 25 игр за неделю',
      'type': 'weekly',
      'requirement_type': 'games_played',
      'requirement_value': 25,
      'reward_type': 'coins',
      'reward_value': 750,
      'is_active': 1,
    });

    await db.insert('challenges', {
      'title': 'Крупный выигрыш',
      'description': 'Выиграйте 1000 монет за неделю',
      'type': 'weekly',
      'requirement_type': 'total_win',
      'requirement_value': 1000,
      'reward_type': 'coins',
      'reward_value': 1000,
      'is_active': 1,
    });

    // Long-term Challenges
    await db.insert('challenges', {
      'title': 'Мастер рулетки',
      'description': 'Выиграйте 100 игр в рулетку',
      'type': 'long_term',
      'requirement_type': 'wins',
      'requirement_value': 100,
      'reward_type': 'coins',
      'reward_value': 5000,
      'is_active': 1,
    });

    await db.insert('challenges', {
      'title': 'Легенда казино',
      'description': 'Сыграйте 500 игр',
      'type': 'long_term',
      'requirement_type': 'games_played',
      'requirement_value': 500,
      'reward_type': 'coins',
      'reward_value': 10000,
      'is_active': 1,
    });

    await db.insert('challenges', {
      'title': 'Миллионер',
      'description': 'Выиграйте 10000 монет',
      'type': 'long_term',
      'requirement_type': 'total_win',
      'requirement_value': 10000,
      'reward_type': 'coins',
      'reward_value': 20000,
      'is_active': 1,
    });
  }

  Future<void> _insertDefaultChallengesForSharedPreferences(SharedPreferences prefs) async {
    final List<Map<String, dynamic>> defaultChallenges = [
      // Daily Challenges
      {'id': 1, 'title': 'Первая победа дня', 'description': 'Выиграйте одну игру', 'type': 'daily', 'requirement_type': 'wins', 'requirement_value': 1, 'reward_type': 'coins', 'reward_value': 50, 'is_active': 1},
      {'id': 2, 'title': 'Азартный игрок', 'description': 'Сыграйте 5 игр', 'type': 'daily', 'requirement_type': 'games_played', 'requirement_value': 5, 'reward_type': 'coins', 'reward_value': 100, 'is_active': 1},
      {'id': 3, 'title': 'Большая ставка', 'description': 'Сделайте ставку на 100 монет', 'type': 'daily', 'requirement_type': 'total_bet', 'requirement_value': 100, 'reward_type': 'coins', 'reward_value': 150, 'is_active': 1},
      // Weekly Challenges
      {'id': 4, 'title': 'Недельный победитель', 'description': 'Выиграйте 10 игр за неделю', 'type': 'weekly', 'requirement_type': 'wins', 'requirement_value': 10, 'reward_type': 'coins', 'reward_value': 500, 'is_active': 1},
      {'id': 5, 'title': 'Недельный игрок', 'description': 'Сыграйте 25 игр за неделю', 'type': 'weekly', 'requirement_type': 'games_played', 'requirement_value': 25, 'reward_type': 'coins', 'reward_value': 750, 'is_active': 1},
      {'id': 6, 'title': 'Крупный выигрыш', 'description': 'Выиграйте 1000 монет за неделю', 'type': 'weekly', 'requirement_type': 'total_win', 'requirement_value': 1000, 'reward_type': 'coins', 'reward_value': 1000, 'is_active': 1},
      // Long-term Challenges
      {'id': 7, 'title': 'Мастер рулетки', 'description': 'Выиграйте 100 игр в рулетку', 'type': 'long_term', 'requirement_type': 'wins', 'requirement_value': 100, 'reward_type': 'coins', 'reward_value': 5000, 'is_active': 1},
      {'id': 8, 'title': 'Легенда казино', 'description': 'Сыграйте 500 игр', 'type': 'long_term', 'requirement_type': 'games_played', 'requirement_value': 500, 'reward_type': 'coins', 'reward_value': 10000, 'is_active': 1},
      {'id': 9, 'title': 'Миллионер', 'description': 'Выиграйте 10000 монет', 'type': 'long_term', 'requirement_type': 'total_win', 'requirement_value': 10000, 'reward_type': 'coins', 'reward_value': 20000, 'is_active': 1},
    ];
    await prefs.setString('challenges', json.encode(defaultChallenges));
    print('Default challenges inserted into SharedPreferences.'); // Debug log
  }

  Future<dynamic> _getData(String key) async {
    final db = await database;
    if (db is SharedPreferences) {
      return db.getString(key) ?? '[]';
    }
    return null;
  }

  Future<void> _setData(String key, String value) async {
    final db = await database;
    if (db is SharedPreferences) {
      await db.setString(key, value);
    }
  }

  Future<int> createUser(Map<String, dynamic> user) async {
    final db = await database;
    if (db is SharedPreferences) {
      final usersJson = await _getData('users');
      final users = List<Map<String, dynamic>>.from(json.decode(usersJson));

      if (users.any((u) => u['username'] == user['username'])) {
        return -1;
      }
      if (users.any((u) => u['email'] == user['email'])) {
        return -2;
      }

      final newId = users.isNotEmpty ? (users.last['id'] as int) + 1 : 1;
      final newUser = {'id': newId, ...user};
      users.add(newUser);

      await _setData('users', json.encode(users));
      return newId;
    } else {
      return await db.insert('users', user);
    }
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    if (db is SharedPreferences) {
      final usersJson = await _getData('users');
      final users = List<Map<String, dynamic>>.from(json.decode(usersJson));
      return users.firstWhereOrNull((user) => user['email'] == email);
    } else {
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [email],
      );
      return maps.isNotEmpty ? maps.first : null;
    }
  }

  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    final db = await database;
    if (db is SharedPreferences) {
      final usersJson = await _getData('users');
      final users = List<Map<String, dynamic>>.from(json.decode(usersJson));
      return users.firstWhereOrNull((user) => user['username'] == username);
    } else {
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [username],
      );
      return maps.isNotEmpty ? maps.first : null;
    }
  }

  Future<void> updateUserBalance(int userId, double newBalance) async {
    final db = await database;
    if (db is SharedPreferences) {
      final usersJson = await _getData('users');
      final users = List<Map<String, dynamic>>.from(json.decode(usersJson));
      final userIndex = users.indexWhere((user) => user['id'] == userId);
      if (userIndex != -1) {
        users[userIndex]['balance'] = newBalance;
        await _setData('users', json.encode(users));
      }
    } else {
      await db.update(
        'users',
        {'balance': newBalance},
        where: 'id = ?',
        whereArgs: [userId],
      );
    }
  }

  Future<void> updateUserData(int userId, Map<String, dynamic> data) async {
    final db = await database;
    if (db is SharedPreferences) {
      final usersJson = await _getData('users');
      final users = List<Map<String, dynamic>>.from(json.decode(usersJson));
      final userIndex = users.indexWhere((user) => user['id'] == userId);
      if (userIndex != -1) {
        users[userIndex].addAll(data);
        await _setData('users', json.encode(users));
      }
    } else {
      await db.update(
        'users',
        data,
        where: 'id = ?',
        whereArgs: [userId],
      );
    }
  }

  Future<void> addGameHistory(Map<String, dynamic> game) async {
    final db = await database;
    if (db is SharedPreferences) {
      final historyJson = await _getData('game_history');
      final history = List<Map<String, dynamic>>.from(json.decode(historyJson));
      final newId = history.isNotEmpty ? (history.last['id'] as int) + 1 : 1;
      final newGame = {
        'id': newId,
        ...game,
        'created_at': DateTime.now().toIso8601String(),
      };
      history.add(newGame);
      await _setData('game_history', json.encode(history));
    } else {
      await db.insert('game_history', {
        ...game,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<List<Map<String, dynamic>>> getGameHistory() async {
    final db = await database;
    if (db is SharedPreferences) {
      final historyJson = await _getData('game_history');
      final history = List<Map<String, dynamic>>.from(json.decode(historyJson));
      history.sort((a, b) => b['created_at'].compareTo(a['created_at']));
      return history;
    } else {
      return await db.query(
        'game_history',
        orderBy: 'created_at DESC',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getUserGameHistory(int userId) async {
    final db = await database;
    if (db is SharedPreferences) {
      final historyJson = await _getData('game_history');
      try {
        final history = List<Map<String, dynamic>>.from(json.decode(historyJson));
        final userHistory = history.where((game) => game['user_id'] == userId).toList();
        userHistory.sort((a, b) => b['created_at'].compareTo(a['created_at']));
        return userHistory;
      } catch (e) {
        print('Error parsing game history: $e');
        return [];
      }
    } else {
      try {
        return await db.query(
          'game_history',
          where: 'user_id = ?',
          whereArgs: [userId],
          orderBy: 'created_at DESC',
        );
      } catch (e) {
        print('Error querying game history: $e');
        return [];
      }
    }
  }

  Future<int> createChallenge(Map<String, dynamic> challenge) async {
    final db = await database;
    if (db is SharedPreferences) {
      final challengesJson = await _getData('challenges');
      final challenges = List<Map<String, dynamic>>.from(json.decode(challengesJson));
      final newId = challenges.isNotEmpty ? (challenges.last['id'] as int) + 1 : 1;
      final newChallenge = {'id': newId, ...challenge};
      challenges.add(newChallenge);
      await _setData('challenges', json.encode(challenges));
      return newId;
    } else {
      return await db.insert('challenges', challenge);
    }
  }

  Future<List<Map<String, dynamic>>> getAllChallenges() async {
    final db = await database;
    if (db is SharedPreferences) {
      final challengesJson = await _getData('challenges');
      return List<Map<String, dynamic>>.from(json.decode(challengesJson));
    } else {
      return await db.query('challenges');
    }
  }

  Future<Map<String, dynamic>?> getUserChallenge(int userId, int challengeId) async {
    final db = await database;
    if (db is SharedPreferences) {
      final userChallengesJson = await _getData('user_challenges');
      final userChallenges = List<Map<String, dynamic>>.from(json.decode(userChallengesJson));
      return userChallenges.firstWhereOrNull(
        (uc) => uc['user_id'] == userId && uc['challenge_id'] == challengeId,
      );
    } else {
      final List<Map<String, dynamic>> maps = await db.query(
        'user_challenges',
        where: 'user_id = ? AND challenge_id = ?',
        whereArgs: [userId, challengeId],
      );
      return maps.isNotEmpty ? maps.first : null;
    }
  }

  Future<List<Map<String, dynamic>>> getUserChallenges(int userId) async {
    final db = await database;
    print('getUserChallenges: userId = $userId'); // Debug log

    if (db is SharedPreferences) {
      print('getUserChallenges: Using SharedPreferences'); // Debug log
      final userChallengesJson = await _getData('user_challenges');
      final challengesJson = await _getData('challenges');
      
      if (userChallengesJson == null || challengesJson == null) {
        print('getUserChallenges: No data found in SharedPreferences'); // Debug log
        return [];
      }

      print('getUserChallenges: userChallengesJson = $userChallengesJson'); // Debug log
      print('getUserChallenges: challengesJson = $challengesJson'); // Debug log
      
      final userChallenges = List<Map<String, dynamic>>.from(json.decode(userChallengesJson));
      final challenges = List<Map<String, dynamic>>.from(json.decode(challengesJson));
      
      // Создаем список всех активных испытаний с прогрессом пользователя
      final List<Map<String, dynamic>> result = [];
      
      for (var challenge in challenges.where((c) => c['is_active'] == 1)) {
        final userChallenge = userChallenges.firstWhere(
          (uc) => uc['user_id'] == userId && uc['challenge_id'] == challenge['id'],
          orElse: () => {
            'user_id': userId,
            'challenge_id': challenge['id'],
            'progress': 0,
            'is_completed': 0,
            'completed_at': null,
          },
        );
        
        result.add({
          ...challenge,
          'progress': userChallenge['progress'],
          'is_completed': userChallenge['is_completed'],
          'completed_at': userChallenge['completed_at'],
        });
      }
      
      print('getUserChallenges: SharedPreferences result = $result'); // Debug log
      return result;
    } else {
      print('getUserChallenges: Using SQFlite'); // Debug log
      final result = await db.rawQuery('''
        SELECT 
          c.*,
          COALESCE(uc.progress, 0) as progress,
          COALESCE(uc.is_completed, 0) as is_completed,
          uc.completed_at
        FROM challenges c
        LEFT JOIN user_challenges uc ON c.id = uc.challenge_id AND uc.user_id = ?
        WHERE c.is_active = 1
        ORDER BY c.type, c.id
      ''', [userId]);
      
      print('getUserChallenges: SQFlite result = $result'); // Debug log
      return result;
    }
  }

  Future<void> createUserChallenge(Map<String, dynamic> userChallenge) async {
    final db = await database;
    if (db is SharedPreferences) {
      final userChallengesJson = await _getData('user_challenges');
      final userChallenges = List<Map<String, dynamic>>.from(json.decode(userChallengesJson));
      final newId = userChallenges.isNotEmpty ? (userChallenges.last['id'] as int) + 1 : 1;
      final newUserChallenge = {'id': newId, ...userChallenge};
      userChallenges.add(newUserChallenge);
      await _setData('user_challenges', json.encode(userChallenges));
    } else {
      await db.insert('user_challenges', userChallenge);
    }
  }

  Future<void> updateUserChallengeProgress(int challengeId, double progress) async {
    final db = await database;
    if (db is SharedPreferences) {
      final challengesJson = await _getData('user_challenges');
      final challenges = List<Map<String, dynamic>>.from(json.decode(challengesJson));
      final challengeIndex = challenges.indexWhere((c) => c['id'] == challengeId);
      if (challengeIndex != -1) {
        challenges[challengeIndex]['progress'] = progress;
        await _setData('user_challenges', json.encode(challenges));
      }
    } else {
      await db.update(
        'user_challenges',
        {'progress': progress},
        where: 'id = ?',
        whereArgs: [challengeId],
      );
    }
  }

  Future<void> markUserChallengeCompleted(int challengeId) async {
    final db = await database;
    if (db is SharedPreferences) {
      final challengesJson = await _getData('user_challenges');
      final challenges = List<Map<String, dynamic>>.from(json.decode(challengesJson));
      final challengeIndex = challenges.indexWhere((c) => c['id'] == challengeId);
      if (challengeIndex != -1) {
        challenges[challengeIndex]['is_completed'] = 1;
        challenges[challengeIndex]['completed_at'] = DateTime.now().toIso8601String();
        await _setData('user_challenges', json.encode(challenges));
      }
    } else {
      await db.update(
        'user_challenges',
        {
          'is_completed': 1,
          'completed_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [challengeId],
      );
    }
  }

  Future<void> close() async {
    final db = await database;
    if (db is Database) {
      await db.close();
    }
     // No close needed for SharedPreferences
  }

  Future<Map<String, dynamic>?> getUserById(int userId) async {
    final db = await database;
    if (db is SharedPreferences) {
      final usersJson = await _getData('users');
      final users = List<Map<String, dynamic>>.from(json.decode(usersJson));
      return users.firstWhereOrNull((user) => user['id'] == userId);
    } else {
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );
      return maps.isNotEmpty ? maps.first : null;
    }
  }

  Future<void> updateChallengeProgress(int userId, String gameType, String challengeType, double value) async {
    final db = await database;
    final userChallenges = await getUserChallenges(userId);
    print('Updating challenge progress for user $userId, game $gameType, type $challengeType, value $value'); // Debug log

    for (var challenge in userChallenges) {
      // Пропускаем уже выполненные испытания
      if (challenge['is_completed'] == 1) {
        print('Challenge ${challenge['id']} is already completed, skipping'); // Debug log
        continue;
      }

      bool shouldUpdate = false;
      double progress = (challenge['progress'] as num).toDouble();

      // Проверяем тип испытания и игру
      if (challenge['type'] == 'daily' || challenge['type'] == 'weekly' || challenge['type'] == 'long_term') {
        // Проверяем, соответствует ли тип игры требованию испытания
        if (gameType != 'roulette' && challenge['requirement_type'] == 'wins') {
          continue; // Пропускаем, если это не рулетка
        }

        switch (challenge['requirement_type']) {
          case 'wins':
            if (challengeType == 'win' && value > 0) {
              progress++;
              shouldUpdate = true;
            }
            break;
          case 'games_played':
            if (challengeType == 'play_games') {
              progress += value;
              shouldUpdate = true;
            }
            break;
          case 'total_bet':
            if (challengeType == 'bet_amount') {
              progress += value;
              shouldUpdate = true;
            }
            break;
          case 'total_win':
            if (challengeType == 'win_amount' && value > 0) {
              progress += value;
              shouldUpdate = true;
            }
            break;
        }
      }

      if (shouldUpdate) {
        print('Updating challenge ${challenge['id']} progress from ${challenge['progress']} to $progress'); // Debug log
        bool isCompleted = progress >= challenge['requirement_value'];
        
        if (db is SharedPreferences) {
          final userChallengesJson = await _getData('user_challenges');
          final userChallengesList = List<Map<String, dynamic>>.from(json.decode(userChallengesJson));
          final ucIndex = userChallengesList.indexWhere(
            (uc) => uc['user_id'] == userId && uc['challenge_id'] == challenge['id']
          );

          if (ucIndex != -1) {
            // Проверяем, не было ли испытание уже выполнено
            if (userChallengesList[ucIndex]['is_completed'] == 1) {
              print('Challenge ${challenge['id']} was already completed in database, skipping'); // Debug log
              continue;
            }

            userChallengesList[ucIndex]['progress'] = progress;
            userChallengesList[ucIndex]['is_completed'] = isCompleted ? 1 : 0;
            userChallengesList[ucIndex]['completed_at'] = isCompleted ? DateTime.now().toIso8601String() : null;
            await _setData('user_challenges', json.encode(userChallengesList));

            // Если испытание выполнено, добавляем награду
            if (isCompleted) {
              final rewardValue = challenge['reward_value'] as int;
              final usersJson = await _getData('users');
              final usersList = List<Map<String, dynamic>>.from(json.decode(usersJson));
              final userIndex = usersList.indexWhere((user) => user['id'] == userId);
              if (userIndex != -1) {
                usersList[userIndex]['balance'] += rewardValue;
                await _setData('users', json.encode(usersList));
                
                // Показываем уведомление о награде
                Get.snackbar(
                  'Испытание выполнено!',
                  'Вы получили ${rewardValue} монет за выполнение испытания "${challenge['title']}"',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                  duration: const Duration(seconds: 5),
                );
              }
            }
          }
        } else {
          // Проверяем текущий статус испытания в базе данных
          final currentStatus = await db.query(
            'user_challenges',
            where: 'user_id = ? AND challenge_id = ?',
            whereArgs: [userId, challenge['id']],
          );

          if (currentStatus.isNotEmpty && currentStatus.first['is_completed'] == 1) {
            print('Challenge ${challenge['id']} was already completed in database, skipping'); // Debug log
            continue;
          }

          await db.update(
            'user_challenges',
            {
              'progress': progress,
              'is_completed': isCompleted ? 1 : 0,
              'completed_at': isCompleted ? DateTime.now().toIso8601String() : null,
            },
            where: 'user_id = ? AND challenge_id = ?',
            whereArgs: [userId, challenge['id']],
          );

          // Если испытание выполнено, добавляем награду
          if (isCompleted) {
            final rewardValue = challenge['reward_value'] as int;
            await db.rawUpdate('''
              UPDATE users 
              SET balance = balance + ? 
              WHERE id = ?
            ''', [rewardValue, userId]);
            
            // Показываем уведомление о награде
            Get.snackbar(
              'Испытание выполнено!',
              'Вы получили ${rewardValue} монет за выполнение испытания "${challenge['title']}"',
              backgroundColor: Colors.green,
              colorText: Colors.white,
              duration: const Duration(seconds: 5),
            );
          }
        }
      }
    }
  }
}

// Challenge-related methods
Future<List<Map<String, dynamic>>> getChallenges() async {
  final _dbHelper = DatabaseHelper.instance;
  final db = await _dbHelper.database;
  if (db is SharedPreferences) {
    final challengesJson = await _dbHelper._getData('challenges');
    return List<Map<String, dynamic>>.from(json.decode(challengesJson));
  }
  return await db.query('challenges', where: 'is_active = ?', whereArgs: [1]);
}

Future<void> initializeUserChallenges(int userId) async {
  final _dbHelper = DatabaseHelper.instance;
  final db = await _dbHelper.database;
  final challenges = await getChallenges();
  
  if (db is SharedPreferences) {
    final userChallengesJson = await _dbHelper._getData('user_challenges');
    final existingUserChallenges = List<Map<String, dynamic>>.from(json.decode(userChallengesJson));
    
    // Создаем множество существующих испытаний пользователя
    final existingChallengeIds = existingUserChallenges
        .where((uc) => uc['user_id'] == userId)
        .map((uc) => uc['challenge_id'])
        .toSet();
    
    // Добавляем только новые испытания
    for (var challenge in challenges) {
      if (!existingChallengeIds.contains(challenge['id'])) {
        await _dbHelper.createUserChallenge({
          'user_id': userId,
          'challenge_id': challenge['id'],
          'progress': 0,
          'is_completed': 0,
        });
      }
    }
  } else {
    // Для SQLite используем INSERT OR IGNORE
    for (var challenge in challenges) {
      await db.insert('user_challenges', {
        'user_id': userId,
        'challenge_id': challenge['id'],
        'progress': 0,
        'is_completed': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}

Future<void> resetDailyChallenges() async {
  final _dbHelper = DatabaseHelper.instance;
  final db = await _dbHelper.database;
  if (db is SharedPreferences) {
    final userChallengesJson = await _dbHelper._getData('user_challenges');
    final userChallenges = List<Map<String, dynamic>>.from(json.decode(userChallengesJson));
    
    // Find daily challenges by looking up challenge details from the challenges list
    final challengesJson = await _dbHelper._getData('challenges');
    final allChallenges = List<Map<String, dynamic>>.from(json.decode(challengesJson));
    final dailyChallengeIds = allChallenges
        .where((c) => c['type'] == 'daily')
        .map((c) => c['id'])
        .toList();

    final userDailyChallenges = userChallenges
        .where((uc) => dailyChallengeIds.contains(uc['challenge_id']))
        .toList();

    for (var challenge in userDailyChallenges) {
      challenge['progress'] = 0;
      challenge['is_completed'] = 0;
      challenge['completed_at'] = null;
    }
    
    await _dbHelper._setData('user_challenges', json.encode(userChallenges));

  } else {
    await db.rawUpdate('''
      UPDATE user_challenges 
      SET progress = 0, is_completed = 0, completed_at = NULL 
      WHERE challenge_id IN (
        SELECT id FROM challenges WHERE type = 'daily'
      )
    ''');
  }
}

Future<void> resetWeeklyChallenges() async {
  final _dbHelper = DatabaseHelper.instance;
  final db = await _dbHelper.database;
  if (db is SharedPreferences) {
    final userChallengesJson = await _dbHelper._getData('user_challenges');
    final userChallenges = List<Map<String, dynamic>>.from(json.decode(userChallengesJson));

    // Find weekly challenges by looking up challenge details from the challenges list
    final challengesJson = await _dbHelper._getData('challenges');
    final allChallenges = List<Map<String, dynamic>>.from(json.decode(challengesJson));
    final weeklyChallengeIds = allChallenges
        .where((c) => c['type'] == 'weekly')
        .map((c) => c['id'])
        .toList();

    final userWeeklyChallenges = userChallenges
        .where((uc) => weeklyChallengeIds.contains(uc['challenge_id']))
        .toList();

    for (var challenge in userWeeklyChallenges) {
      challenge['progress'] = 0;
      challenge['is_completed'] = 0;
      challenge['completed_at'] = null;
    }
    
    await _dbHelper._setData('user_challenges', json.encode(userChallenges));
  } else {
    await db.rawUpdate('''
      UPDATE user_challenges 
      SET progress = 0, is_completed = 0, completed_at = NULL 
      WHERE challenge_id IN (
        SELECT id FROM challenges WHERE type = 'weekly'
      )
    ''');
  }
}