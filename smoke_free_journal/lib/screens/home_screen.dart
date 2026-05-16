import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../config/app_colors.dart';
import 'breathing_exercise.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _lastSmokeTime;
  Map<DateTime, int> _cigarettesPerDay = {};
  List<DateTime> _smokeTimestamps = [];
  Timer? _timer;
  Box _box = Hive.box('smokingData');
  List<Map<String, dynamic>> _journalEntries = [];
  Set<DateTime> _successfulDays = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadData();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final storedMap = _box.get('cigarettesPerDay');
    if (storedMap != null) {
      final decoded = jsonDecode(storedMap) as Map<String, dynamic>;
      final newMap = <DateTime, int>{};
      for (var entry in decoded.entries) {
        final date = DateTime.parse(entry.key);
        newMap[DateTime(date.year, date.month, date.day)] = entry.value as int;
      }
      final lastSmoke = _box.get('lastSmokeTime');
      setState(() {
        _cigarettesPerDay = newMap;
        if (lastSmoke != null) {
          _lastSmokeTime = DateTime.parse(lastSmoke);
        }
      });
    } else {
      _loadTestData();
      await _saveData();
    }

    final timestampsStored = _box.get('smokeTimestamps');
    if (timestampsStored != null) {
      final decoded = jsonDecode(timestampsStored) as List<dynamic>;
      _smokeTimestamps = decoded.map((e) => DateTime.parse(e)).toList();
    } else {
      _smokeTimestamps = [];
    }

    final journalStored = _box.get('journalEntries');
    if (journalStored != null) {
      final decoded = jsonDecode(journalStored) as List<dynamic>;
      _journalEntries = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      _journalEntries = [];
    }
    _updateSuccessfulDays();
  }

  void _updateSuccessfulDays() {
    final Map<DateTime, int> triggers = {};
    final Map<DateTime, int> relapses = {};
    for (var entry in _journalEntries) {
      final date = DateTime.parse(entry['date']);
      final day = DateTime(date.year, date.month, date.day);
      if (entry['type'] == 'trigger') {
        triggers[day] = (triggers[day] ?? 0) + 1;
      } else if (entry['type'] == 'relapse') {
        relapses[day] = (relapses[day] ?? 0) + 1;
      }
    }
    _successfulDays = {};
    for (var day in {...triggers.keys, ...relapses.keys}) {
      final t = triggers[day] ?? 0;
      final r = relapses[day] ?? 0;
      if (t > r) {
        _successfulDays.add(day);
      }
    }
  }

  Future<void> _saveData() async {
    final stringMap = <String, int>{};
    for (var entry in _cigarettesPerDay.entries) {
      final key = '${entry.key.year}-${entry.key.month.toString().padLeft(2, '0')}-${entry.key.day.toString().padLeft(2, '0')}';
      stringMap[key] = entry.value;
    }
    final encoded = jsonEncode(stringMap);
    await _box.put('cigarettesPerDay', encoded);
    if (_lastSmokeTime != null) {
      await _box.put('lastSmokeTime', _lastSmokeTime!.toIso8601String());
    }
    await _box.put('smokeTimestamps', jsonEncode(_smokeTimestamps.map((e) => e.toIso8601String()).toList()));
    await _box.flush();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _loadTestData() {
  final now = DateTime.now();
  _cigarettesPerDay.clear();
  _smokeTimestamps.clear();
  _journalEntries.clear();

  final List<Map<String, dynamic>> testDays = [
    {'daysAgo': 1, 'count': 5, 'times': ['08:15', '10:30', '13:00', '16:20', '20:00']},
    {'daysAgo': 2, 'count': 3, 'times': ['09:00', '14:00', '19:30']},
    {'daysAgo': 3, 'count': 8, 'times': ['07:45', '09:30', '11:00', '13:30', '15:00', '17:45', '20:30', '22:10']},
    {'daysAgo': 4, 'count': 2, 'times': ['10:00', '18:00']},
    {'daysAgo': 5, 'count': 12, 'times': ['06:30', '08:00', '09:15', '10:30', '12:00', '14:00', '15:30', '17:00', '18:45', '20:15', '21:30', '23:00']},
    {'daysAgo': 6, 'count': 1, 'times': ['12:00']},
    {'daysAgo': 7, 'count': 4, 'times': ['08:30', '12:45', '16:00', '20:15']},
  ];

  for (var dayData in testDays) {
    final daysAgo = (dayData['daysAgo'] as num).toInt();
    final day = DateTime(now.year, now.month, now.day - daysAgo);
    final count = (dayData['count'] as num).toInt();
    _cigarettesPerDay[day] = count;
    for (var timeStr in dayData['times'] as List<String>) {
      final parts = timeStr.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final ts = DateTime(day.year, day.month, day.day, h, m);
      _smokeTimestamps.add(ts);
    }
  }

  final lastMonth1 = DateTime(now.year, now.month - 1, 15);
  _cigarettesPerDay[lastMonth1] = 6;
  _smokeTimestamps.addAll([
    DateTime(lastMonth1.year, lastMonth1.month, lastMonth1.day, 9, 0),
    DateTime(lastMonth1.year, lastMonth1.month, lastMonth1.day, 11, 30),
    DateTime(lastMonth1.year, lastMonth1.month, lastMonth1.day, 14, 0),
    DateTime(lastMonth1.year, lastMonth1.month, lastMonth1.day, 16, 30),
    DateTime(lastMonth1.year, lastMonth1.month, lastMonth1.day, 19, 0),
    DateTime(lastMonth1.year, lastMonth1.month, lastMonth1.day, 21, 30),
  ]);

  final lastMonth2 = DateTime(now.year, now.month - 1, 20);
  _cigarettesPerDay[lastMonth2] = 3;
  _smokeTimestamps.addAll([
    DateTime(lastMonth2.year, lastMonth2.month, lastMonth2.day, 10, 15),
    DateTime(lastMonth2.year, lastMonth2.month, lastMonth2.day, 15, 45),
    DateTime(lastMonth2.year, lastMonth2.month, lastMonth2.day, 20, 0),
  ]);

  _smokeTimestamps.sort();
  _lastSmokeTime = _smokeTimestamps.isNotEmpty ? _smokeTimestamps.last : null;

  _journalEntries.addAll([
    {
      'date': DateTime(now.year, now.month, now.day - 1, 11, 0).toIso8601String(),
      'type': 'trigger',
      'content': 'Вместо сигареты выпил стакан воды',
      'title': 'Вода вместо сигареты',
    },
    {
      'date': DateTime(now.year, now.month, now.day - 2, 15, 20).toIso8601String(),
      'type': 'relapse',
      'content': 'Сорвался после стрессового созвона',
      'title': 'Срыв после работы',
    },
    {
      'date': DateTime(now.year, now.month, now.day - 3, 9, 0).toIso8601String(),
      'type': 'note',
      'content': 'Сегодня чувствую себя хорошо, тяга уменьшилась',
      'title': 'Позитивный день',
    },
    {
      'date': DateTime(now.year, now.month, now.day - 4, 20, 45).toIso8601String(),
      'type': 'trigger',
      'content': 'Сделал дыхательное упражнение на 60 секунд',
      'title': 'Дыхание помогло',
    },
    {
      'date': DateTime(now.year, now.month, now.day - 5, 8, 30).toIso8601String(),
      'type': 'relapse',
      'content': 'Закурил за компанию в баре',
      'title': 'Социальное давление',
    },
    {
      'date': DateTime(now.year, now.month, now.day - 6, 13, 15).toIso8601String(),
      'type': 'trigger',
      'content': 'Отвлёкся на мини-игру вместо курения',
      'title': 'Игра помогла',
    },
    {
      'date': DateTime(now.year, now.month, now.day - 7, 17, 0).toIso8601String(),
      'type': 'note',
      'content': 'Первый день тестовых данных',
      'title': 'Начало',
    },
  ]);
}

  void _addCigarette() async {
    final today = DateTime.now();
    setState(() {
      _cigarettesPerDay.update(
        DateTime(today.year, today.month, today.day),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      _lastSmokeTime = today;
      _smokeTimestamps.add(today);
    });
    await _saveData();
  }

  void _removeLastCigarette() async {
    if (_smokeTimestamps.isEmpty) return;
    final lastTimestamp = _smokeTimestamps.last;
    final day = DateTime(lastTimestamp.year, lastTimestamp.month, lastTimestamp.day);
    setState(() {
      _smokeTimestamps.removeLast();
      if (_cigarettesPerDay.containsKey(day) && _cigarettesPerDay[day]! > 0) {
        final newCount = _cigarettesPerDay[day]! - 1;
        if (newCount == 0) {
          _cigarettesPerDay.remove(day);
          _lastSmokeTime = _smokeTimestamps.isNotEmpty ? _smokeTimestamps.last : null;
        } else {
          _cigarettesPerDay[day] = newCount;
        }
      }
    });
    await _saveData();
  }

  void _showReplacementDialog() {
    TextEditingController textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Замена', style: TextStyle(color: AppColors.text)),
        content: TextField(
          controller: textController,
          maxLines: 4,
          style: const TextStyle(color: AppColors.text),
          decoration: const InputDecoration(
            hintText: 'Что вы сделали вместо курения?',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final content = textController.text.trim();
              if (content.isNotEmpty) {
                _addReplacement(content);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _addReplacement(String content) async {
    final now = DateTime.now();
    final title = content.split('\n').first.isEmpty ? 'Без названия' : content.split('\n').first;
    final entry = {
      'date': now.toIso8601String(),
      'type': 'trigger',
      'content': content,
      'title': title,
    };
    _journalEntries.insert(0, entry);
    await _box.put('journalEntries', jsonEncode(_journalEntries));
    await _box.flush();
    _updateSuccessfulDays();
    setState(() {});
  }

  String _getTimeSinceLastSmoke() {
    if (_lastSmokeTime == null) return 'Нет данных';
    final difference = DateTime.now().difference(_lastSmokeTime!);
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    return '${hours}ч ${minutes}м';
  }

  String _getLastSmokeTimestamp() {
    if (_lastSmokeTime == null) return '—';
    return '${_lastSmokeTime!.hour.toString().padLeft(2, '0')}:${_lastSmokeTime!.minute.toString().padLeft(2, '0')}';
  }

  int _getCigarettesForSelectedDay() {
    if (_selectedDay == null) return 0;
    final key = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    return _cigarettesPerDay[key] ?? 0;
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_getMonthName(date.month)} ${date.year} года';
  }

  String _getMonthName(int month) {
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    return months[month - 1];
  }

  String _getMotivationalMessage(int count) {
    if (count <= 3) return 'Можно и меньше 🎯';
    if (count <= 7) return 'Попробуйте сократить 💪';
    if (count <= 10) return 'Это много для одного дня ⚠️';
    return 'Срочно нужна помощь! 🆘';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final calendarWidth = screenWidth - 32;
    final calendarHeight = MediaQuery.of(context).size.height * 0.55;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Главная'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: calendarWidth,
              height: calendarHeight,
              constraints: const BoxConstraints(minHeight: 400, maxHeight: 600),
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
                color: AppColors.surface,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: TableCalendar(
                  firstDay: DateTime(2020),
                  lastDay: DateTime(2030),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                  },
                  calendarStyle: CalendarStyle(
                    selectedDecoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    defaultDecoration: const BoxDecoration(shape: BoxShape.circle),
                    weekendDecoration: const BoxDecoration(shape: BoxShape.circle),
                    defaultTextStyle: const TextStyle(
                      fontSize: 16,
                      color: AppColors.text,
                      fontWeight: FontWeight.normal,
                    ),
                    weekendTextStyle: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.normal,
                    ),
                    selectedTextStyle: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    todayTextStyle: const TextStyle(
                      fontSize: 16,
                      color: AppColors.text,
                      fontWeight: FontWeight.bold,
                    ),
                    outsideTextStyle: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary.withOpacity(0.5),
                    ),
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                    leftChevronIcon: const Icon(
                      Icons.chevron_left,
                      color: AppColors.primary,
                    ),
                    rightChevronIcon: const Icon(
                      Icons.chevron_right,
                      color: AppColors.primary,
                    ),
                    leftChevronPadding: const EdgeInsets.all(8),
                    rightChevronPadding: const EdgeInsets.all(8),
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      final dateKey = DateTime(day.year, day.month, day.day);
                      final cigarettes = _cigarettesPerDay[dateKey];
                      final isSelected = isSameDay(day, _selectedDay);
                      final isToday = isSameDay(day, DateTime.now());
                      final hasCigarettes = cigarettes != null && cigarettes > 0;

                      BoxDecoration? decoration;
                      if (isSelected) {
                        decoration = const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        );
                      } else if (isToday) {
                        decoration = BoxDecoration(
                          color: AppColors.primary.withOpacity(0.3),
                          shape: BoxShape.circle,
                        );
                      }

                      Widget dayWidget = Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 16,
                            color: isSelected ? Colors.white : AppColors.text,
                            fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );

                      if (hasCigarettes) {
                        dayWidget = Stack(
                          alignment: Alignment.center,
                          children: [
                            dayWidget,
                            Positioned(
                              bottom: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.warning,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$cigarettes',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      return Container(decoration: decoration, child: dayWidget);
                    },
                    markerBuilder: (context, date, events) {
                      final dateKey = DateTime(date.year, date.month, date.day);
                      final cigarettes = _cigarettesPerDay[dateKey];
                      final isSuccessful = _successfulDays.contains(dateKey);

                      return Stack(
                        children: [
                          if (cigarettes != null && cigarettes > 0)
                            Positioned(
                              left: 1,
                              bottom: 0,
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.warning,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          if (isSuccessful)
                            Positioned(
                              right: 1,
                              bottom: 0,
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: calendarWidth,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
                color: AppColors.surface,
              ),
              child: _buildInfoPanelContent(),
            ),
            const SizedBox(height: 20),
            Container(
              width: calendarWidth,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStyledButton(
                          label: '+ СИГАРЕТА',
                          icon: Icons.smoking_rooms,
                          onPressed: _addCigarette,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStyledButton(
                          label: '- СИГАРЕТА',
                          icon: Icons.remove,
                          onPressed: _removeLastCigarette,
                          color: AppColors.warning.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStyledButton(
                          label: 'ДЫХАТЕЛЬНАЯ ТЕХНИКА',
                          icon: Icons.air,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const BreathingExerciseScreen()),
                            );
                          },
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStyledButton(
                          label: 'ЗАМЕНА',
                          icon: Icons.self_improvement,
                          onPressed: _showReplacementDialog,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPanelContent() {
    final cigarettesCount = _getCigarettesForSelectedDay();
    final isToday = _selectedDay != null && isSameDay(_selectedDay, DateTime.now());
    final lastTime = _getLastSmokeTimestamp();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (cigarettesCount == 0)
          Column(
            children: [
              const Icon(Icons.celebration, size: 48, color: AppColors.success),
              const SizedBox(height: 12),
              Text(
                isToday ? '🎉 Вы сегодня не курили!' : 'В этот день не было сигарет',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isToday
                    ? 'Отличная работа! Продолжайте в том же духе! 💪'
                    : 'Отличный день, продолжайте в том же духе! 🌟',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          )
        else
          Column(
            children: [
              const Icon(Icons.smoking_rooms, size: 48, color: AppColors.warning),
              const SizedBox(height: 12),
              Text(
                'Выкуренo сигарет: $cigarettesCount',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Сегодня: ${_formatDate(_selectedDay!)}',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '🚬 ${_getMotivationalMessage(cigarettesCount)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              'Последняя: $lastTime',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const StatsScreen()),
            );
          },
          icon: const Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
          label: const Text(
            'Подробнее',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStyledButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        shadowColor: color.withOpacity(0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}