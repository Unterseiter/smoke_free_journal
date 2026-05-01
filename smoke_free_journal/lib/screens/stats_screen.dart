import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../config/app_colors.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Box _box = Hive.box('smokingData');
  Map<DateTime, int> _cigarettesPerDay = {};
  List<Map<String, dynamic>> _journalEntries = [];
  String _selectedPeriod = 'week'; // week, month, 3months, 6months, year, all

  final Map<String, int> _periodDays = {
    'week': 7,
    'month': 30,
    '3months': 90,
    '6months': 180,
    'year': 365,
    'all': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final cigStored = _box.get('cigarettesPerDay');
    if (cigStored != null) {
      final decoded = jsonDecode(cigStored) as Map<String, dynamic>;
      final newMap = <DateTime, int>{};
      decoded.forEach((key, value) {
        final date = DateTime.parse(key);
        newMap[DateTime(date.year, date.month, date.day)] = value as int;
      });
      _cigarettesPerDay = newMap;
    }
    final journalStored = _box.get('journalEntries');
    if (journalStored != null) {
      final decoded = jsonDecode(journalStored) as List<dynamic>;
      _journalEntries = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    setState(() {});
  }

  List<FlSpot> _buildFlSpots() {
    final now = DateTime.now();
    int days;
    if (_selectedPeriod == 'all') {
      if (_cigarettesPerDay.isEmpty) return [];
      final earliest = _cigarettesPerDay.keys.reduce((a, b) => a.isBefore(b) ? a : b);
      days = now.difference(earliest).inDays + 1;
      if (days < 7) days = 7;
    } else {
      days = _periodDays[_selectedPeriod]!;
    }
    final spots = <FlSpot>[];
    for (int i = days - 1; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      final count = _cigarettesPerDay[day] ?? 0;
      spots.add(FlSpot((days - 1 - i).toDouble(), count.toDouble()));
    }
    return spots;
  }

  double _getMaxY() {
    double max = 0;
    for (var spot in _buildFlSpots()) {
      if (spot.y > max) max = spot.y;
    }
    return max + 2;
  }

  List<String> _getDayLabels() {
    final now = DateTime.now();
    int days;
    if (_selectedPeriod == 'all') {
      if (_cigarettesPerDay.isEmpty) return [];
      final earliest = _cigarettesPerDay.keys.reduce((a, b) => a.isBefore(b) ? a : b);
      days = now.difference(earliest).inDays + 1;
      if (days < 7) days = 7;
    } else {
      days = _periodDays[_selectedPeriod]!;
    }
    return List.generate(days, (i) {
      final day = DateTime(now.year, now.month, now.day - (days - 1 - i));
      return '${day.day}.${day.month}';
    });
  }

  int _getTotalTriggers() {
    return _journalEntries.where((e) => e['type'] == 'trigger').length;
  }

  int _getTotalRelapses() {
    return _journalEntries.where((e) => e['type'] == 'relapse').length;
  }

  @override
  Widget build(BuildContext context) {
    final spots = _buildFlSpots();
    final maxY = _getMaxY();
    final labels = _getDayLabels();
    final totalTriggers = _getTotalTriggers();
    final totalRelapses = _getTotalRelapses();
    final totalAttempts = totalTriggers + totalRelapses;
    final successRate = totalAttempts > 0 ? (totalTriggers / totalAttempts * 100).round() : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Статистика'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Неделя'),
                  selected: _selectedPeriod == 'week',
                  onSelected: (_) => setState(() => _selectedPeriod = 'week'),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(color: _selectedPeriod == 'week' ? Colors.white : AppColors.text),
                ),
                ChoiceChip(
                  label: const Text('Месяц'),
                  selected: _selectedPeriod == 'month',
                  onSelected: (_) => setState(() => _selectedPeriod = 'month'),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(color: _selectedPeriod == 'month' ? Colors.white : AppColors.text),
                ),
                ChoiceChip(
                  label: const Text('3 мес'),
                  selected: _selectedPeriod == '3months',
                  onSelected: (_) => setState(() => _selectedPeriod = '3months'),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(color: _selectedPeriod == '3months' ? Colors.white : AppColors.text),
                ),
                ChoiceChip(
                  label: const Text('Полгода'),
                  selected: _selectedPeriod == '6months',
                  onSelected: (_) => setState(() => _selectedPeriod = '6months'),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(color: _selectedPeriod == '6months' ? Colors.white : AppColors.text),
                ),
                ChoiceChip(
                  label: const Text('Год'),
                  selected: _selectedPeriod == 'year',
                  onSelected: (_) => setState(() => _selectedPeriod = 'year'),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(color: _selectedPeriod == 'year' ? Colors.white : AppColors.text),
                ),
                ChoiceChip(
                  label: const Text('Всё время'),
                  selected: _selectedPeriod == 'all',
                  onSelected: (_) => setState(() => _selectedPeriod = 'all'),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(color: _selectedPeriod == 'all' ? Colors.white : AppColors.text),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: SizedBox(
                height: 220,
                child: spots.isEmpty
                    ? const Center(child: Text('Нет данных', style: TextStyle(color: AppColors.textSecondary)))
                    : LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: maxY > 5 ? (maxY / 5).ceilToDouble() : 1,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: AppColors.textSecondary.withOpacity(0.1),
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                getTitlesWidget: (value, meta) => Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: (spots.length / 5).ceilToDouble().clamp(1, double.infinity),
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index >= 0 && index < labels.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(labels[index], style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: AppColors.warning,
                              barWidth: 2,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                                  radius: 3,
                                  color: AppColors.warning,
                                  strokeWidth: 0,
                                ),
                              ),
                            ),
                          ],
                          minY: 0,
                          maxY: maxY.toDouble(),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.self_improvement, size: 32, color: AppColors.success),
                        const SizedBox(height: 8),
                        Text('$totalTriggers', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.success)),
                        const Text('Успешных замен', style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.smoking_rooms, size: 32, color: AppColors.warning),
                        const SizedBox(height: 8),
                        Text('$totalRelapses', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.warning)),
                        const Text('Срывов', style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (totalAttempts > 0) ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Эффективность замен: $successRate%',
                  style: const TextStyle(fontSize: 16, color: AppColors.text),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}