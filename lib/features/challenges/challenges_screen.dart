import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({Key? key}) : super(key: key);

  @override
  _ChallengesScreenState createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  late TabController _tabController;
  List<Map<String, dynamic>> _challenges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadChallenges();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChallenges() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.getCurrentUser();
      print('Current user: $user');
      
      if (user != null) {
        final challenges = await _authService.getUserChallenges(user['id']);
        print('Loaded challenges: $challenges');
        
        setState(() {
          _challenges = challenges;
          _isLoading = false;
        });
      } else {
        Get.offAll(() => const LoginScreen());
      }
    } catch (e) {
      print('Error loading challenges: $e');
      setState(() => _isLoading = false);
      Get.snackbar(
        'Ошибка',
        'Не удалось загрузить испытания',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  List<Map<String, dynamic>> _getChallengesByType(String type) {
    return _challenges.where((c) => c['type'] == type).toList();
  }

  String _getProgressText(Map<String, dynamic> challenge) {
    final progress = challenge['progress'] ?? 0;
    final requirement = challenge['requirement_value'];
    return '$progress/$requirement';
  }

  double _getProgressPercentage(Map<String, dynamic> challenge) {
    final progress = challenge['progress'] ?? 0;
    final requirement = challenge['requirement_value'];
    return progress / requirement;
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
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Get.back(),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Испытания',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: const [
                  Tab(text: 'Ежедневные'),
                  Tab(text: 'Еженедельные'),
                  Tab(text: 'Долгосрочные'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildChallengesList('daily'),
                    _buildChallengesList('weekly'),
                    _buildChallengesList('long_term'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChallengesList(String type) {
    final challenges = _getChallengesByType(type);
    
    if (challenges.isEmpty) {
      return const Center(
        child: Text(
          'Нет доступных испытаний',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: challenges.length,
      itemBuilder: (context, index) {
        final challenge = challenges[index];
        final isCompleted = challenge['is_completed'] == 1;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: isCompleted ? Border.all(color: Colors.green, width: 2) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            challenge['title'],
                            style: TextStyle(
                              color: isCompleted ? Colors.green : Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Выполнено',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      challenge['description'],
                      style: TextStyle(
                        color: isCompleted ? Colors.green.withOpacity(0.7) : Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isCompleted ? 'Выполнено' : _getProgressText(challenge),
                          style: TextStyle(
                            color: isCompleted ? Colors.green : Colors.white70,
                            fontSize: 14,
                            fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        Text(
                          'Награда: ${challenge['reward_value']} монет',
                          style: TextStyle(
                            color: isCompleted ? Colors.green : Colors.green,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isCompleted)
                LinearProgressIndicator(
                  value: _getProgressPercentage(challenge),
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                ),
            ],
          ),
        );
      },
    );
  }
}