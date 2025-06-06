import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/database/database_helper.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class AuthService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  // final _prefs = SharedPreferences.getInstance();

  Future<bool> register(String username, String email, String password) async {
    try {
      print('Starting registration for username: $username, email: $email');

      // Check if username exists
      final existingUserByUsername = await _dbHelper.getUserByUsername(username);
      print('Existing user by username: $existingUserByUsername');
      if (existingUserByUsername != null) {
        print('Username already exists: $username');
        return false;
      }

      // Check if email exists
      final existingUserByEmail = await _dbHelper.getUserByEmail(email);
      print('Existing user by email: $existingUserByEmail');
      if (existingUserByEmail != null) {
        print('Email already exists: $email');
        return false;
      }

      // Create new user
      print('Creating new user...');
      final userId = await _dbHelper.createUser({
        'username': username,
        'email': email,
        'password': password,
        'balance': 0.0,
      });
      
      print('Created user with ID: $userId');

      if (userId > 0) {
        // Initialize user challenges
        await initializeUserChallenges(userId);
        print('Registration successful for user: $username');
        return true;
      } else {
        print('Failed to create user: $username, userId: $userId');
        return false;
      }
    } catch (e) {
      print('Registration error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final user = await _dbHelper.getUserByEmail(email);
      if (user != null && user['password'] == password) {
        // Сохраняем данные пользователя
        await _secureStorage.write(key: 'user_id', value: user['id'].toString());
        await _secureStorage.write(key: 'username', value: user['username']);

        // Сохраняем полные данные пользователя в SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user', json.encode(user));

        // Инициализируем испытания для пользователя после успешного входа
        await initializeUserChallenges(user['id']);
        
        print('Login successful for user: ${user['username']}');
        return user;
      }
      print('Login failed for email: $email');
      return null;
    } catch (e) {
      print('Error during login: $e');
      return null;
    }
  }

  Future<void> logout() async {
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    print('User logged out.');
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        final user = json.decode(userJson);
        // Обновляем данные пользователя из базы данных
        final updatedUser = await _dbHelper.getUserById(user['id']);
        if (updatedUser != null) {
          await prefs.setString('current_user', json.encode(updatedUser));
          return Map<String, dynamic>.from(updatedUser);
        }
        return Map<String, dynamic>.from(user);
      }
      return null;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
    final userId = await _secureStorage.read(key: 'user_id');
    return userId != null;
  }

  Future<Map<String, dynamic>?> getUser(String identifier) async {
    try {
      // Сначала пробуем найти пользователя по email
      var user = await _dbHelper.getUserByEmail(identifier);
      
      // Если не нашли по email, пробуем по username
      if (user == null) {
        user = await _dbHelper.getUserByUsername(identifier);
      }
      
      return user; // Убедимся, что возвращаем Map<String, dynamic> или null
    } catch (e) {
      print('Get user error: $e');
      return null;
    }
  }

  Future<void> updateUserBalance(double newBalance) async {
    try {
      final user = await getCurrentUser();
      if (user != null) {
        // Обновляем баланс в базе данных
        await _dbHelper.updateUserBalance(user['id'], newBalance);
        
        // Обновляем данные пользователя в SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        user['balance'] = newBalance;
        await prefs.setString('current_user', json.encode(user));
      } else {
        throw Exception('User not found');
      }
    } catch (e) {
      print('Error updating balance: $e');
      throw e;
    }
  }

  Future<void> updateUserProfile({
    required String username,
    required String email,
    String? avatarUrl,
  }) async {
    try {
      final currentUser = await getCurrentUser();
      if (currentUser != null) {
        // Проверяем, не занято ли новое имя пользователя
        if (username != currentUser['username']) {
          final existingUser = await _dbHelper.getUserByUsername(username);
          if (existingUser != null) {
            throw Exception('Username already exists');
          }
        }

        // Проверяем, не занят ли новый email
        if (email != currentUser['email']) {
          final existingUser = await _dbHelper.getUserByEmail(email);
          if (existingUser != null) {
            throw Exception('Email already exists');
          }
        }

        final updatedData = {
          'username': username,
          'email': email,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
        };
        
        await _dbHelper.updateUserData(
          currentUser['id'], // Используем ID из текущего пользователя
          updatedData,
        );

        final prefs = await SharedPreferences.getInstance();

        final updatedUser = await _dbHelper.getUserById(currentUser['id']);
        if (updatedUser != null) {
           await prefs.setString('current_user', json.encode(updatedUser));
        }

      } else {
        throw Exception('User not found');
      }
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  Future<void> initializeUserChallenges(int userId) async {
    try {
      final allChallenges = await _dbHelper.getAllChallenges();
      final userChallenges = await _dbHelper.getUserChallenges(userId);

      for (var challenge in allChallenges) {
        final existingUserChallenge = userChallenges.firstWhereOrNull(
          (uc) => uc['challenge_id'] == challenge['id'],
        );

        if (existingUserChallenge == null) {
          await _dbHelper.createUserChallenge({
            'user_id': userId,
            'challenge_id': challenge['id'],
            'progress': 0,
            'is_completed': 0,
          });
        }
      }
    } catch (e) {
      print('Error initializing user challenges: $e');
    }
  }

  Future<void> updateChallengeProgress(
    int userId,
    String gameType,
    String progressType,
    double progressIncrease,
  ) async {
    try {
      print('Updating challenge progress: userId=$userId, gameType=$gameType, progressType=$progressType, progressIncrease=$progressIncrease');

      final userChallenges = await _dbHelper.getUserChallenges(userId);
      print('User challenges: $userChallenges');

      for (var challenge in userChallenges) {
        if (challenge['is_completed'] == 1) continue;

        bool shouldUpdate = false;
        double currentProgress = (challenge['progress'] as num).toDouble();

        if (challenge['type'] == 'daily' || challenge['type'] == 'weekly' || challenge['type'] == 'long_term') {
          switch (challenge['requirement_type']) {
            case 'wins':
              if (progressType == 'win' && progressIncrease > 0) {
                currentProgress++;
                shouldUpdate = true;
              }
              break;
            case 'games_played':
              if (progressType == 'play_games') {
                currentProgress += progressIncrease;
                shouldUpdate = true;
              }
              break;
            case 'total_bet':
              if (progressType == 'bet_amount') {
                currentProgress += progressIncrease;
                shouldUpdate = true;
              }
              break;
            case 'total_win':
              if (progressType == 'win_amount' && progressIncrease > 0) {
                currentProgress += progressIncrease;
                shouldUpdate = true;
              }
              break;
          }
        }

        if (shouldUpdate) {
          print('Updating challenge ${challenge['id']} progress from ${challenge['progress']} to $currentProgress');
          
          bool isCompleted = currentProgress >= challenge['requirement_value'];

          await _dbHelper.updateUserChallengeProgress(challenge['id'], currentProgress);

          if (isCompleted) {
            await _dbHelper.markUserChallengeCompleted(challenge['id']);

            final rewardValue = challenge['reward_value'] as int;
            final user = await _dbHelper.getUserById(userId);
            if (user != null) {
              final newBalance = user['balance'] + rewardValue;
              await updateUserBalance(newBalance);

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
    } catch (e) {
      print('Error updating challenge progress: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllChallenges() async {
    try {
      final user = await getCurrentUser();
      if (user != null) {
        return await _dbHelper.getUserChallenges(user['id']);
      }
      return [];
    } catch (e) {
      print('Error getting challenges: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserChallenges(int userId) async {
    try {
      return await _dbHelper.getUserChallenges(userId);
    } catch (e) {
      print('Error getting user challenges: $e');
      return [];
    }
  }


  // Future<Map<String, dynamic>?> getUserById(int userId) async { ... }
}

// extension DatabaseHelperExtensions on DatabaseHelper {
//   Future<Map<String, dynamic>?> getUserById(int userId) async {
//     final db = await database;
//     if (db is SharedPreferences) {
//       final usersJson = db.getString('users') ?? '[]';
//       final users = List<Map<String, dynamic>>.from(json.decode(usersJson));
//       return users.firstWhereOrNull((user) => user['id'] == userId);
//     } else {
//       final List<Map<String, dynamic>> maps = await db.query(
//         'users',
//         where: 'id = ?',
//         whereArgs: [userId],
//       );
//       return maps.isNotEmpty ? maps.first : null;
//     }
//   }
// } 