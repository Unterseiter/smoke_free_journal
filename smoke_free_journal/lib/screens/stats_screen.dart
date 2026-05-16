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
  List<DateTime> _smokeTimestamps = [];
  List<Map<String, dynamic>> _journalEntries = [];
  String _selectedPeriod = 'week';
  DateTime? _selectedDay; // для режима "День"

  final Map<String, int> _periodDays = {
    'day': 1,
    'week': 7,
    'month': 30,
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
    }

    _selectedDay = DateTime.now();
    setState(() {});
  }

  // ---------- Почасовой график для конкретного дня ----------
  List<FlSpot> _buildHourlySpots() {
    if (_selectedDay == null) return [];
    final day = _selectedDay!;
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final Map<int, int> hourCounts = {};
    for (var ts in _smokeTimestamps) {
      if (ts.isAfter(dayStart) && ts.isBefore(dayEnd)) {
        hourCounts[ts.hour] = (hourCounts[ts.hour] ?? 0) + 1;
      }
    }
    final spots = <FlSpot>[];
    for (int h = 0; h < 24; h++) {
      spots.add(FlSpot(h.toDouble(), (hourCounts[h] ?? 0).toDouble()));
    }
    return spots;
  }

  // ---------- Дневной график для периода ----------
  List<FlSpot> _buildDailySpots() {
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

  List<String> _getDailyLabels() {
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

  DateTime? _getDateByIndex(int index) {
    final now = DateTime.now();
    int days;
    if (_selectedPeriod == 'all') {
      if (_cigarettesPerDay.isEmpty) return null;
      final earliest = _cigarettesPerDay.keys.reduce((a, b) => a.isBefore(b) ? a : b);
      days = now.difference(earliest).inDays + 1;
      if (days < 7) days = 7;
    } else {
      days = _periodDays[_selectedPeriod]!;
    }
    if (index < 0 || index >= days) return null;
    return DateTime(now.year, now.month, now.day - (days - 1 - index));
  }

  // ---------- Подсчёт замен и сигарет за выбранный промежуток ----------
  int _countReplacements() {
    if (_selectedPeriod == 'day' && _selectedDay != null) {
      // За конкретный день
      final day = _selectedDay!;
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      return _journalEntries.where((e) {
        if (e['type'] != 'trigger') return false;
        final t = DateTime.parse(e['date']);
        return t.isAfter(dayStart) && t.isBefore(dayEnd);
      }).length;
    } else {
      // За весь период (неделя, месяц, ...) – по дням
      final start = _getPeriodStart();
      final end = DateTime.now();
      return _journalEntries.where((e) {
        if (e['type'] != 'trigger') return false;
        final t = DateTime.parse(e['date']);
        return t.isAfter(start) && t.isBefore(end.add(const Duration(days: 1)));
      }).length;
    }
  }

  int _countCigarettes() {
    if (_selectedPeriod == 'day' && _selectedDay != null) {
      final day = _selectedDay!;
      return _cigarettesPerDay[DateTime(day.year, day.month, day.day)] ?? 0;
    } else {
      final start = _getPeriodStart();
      final end = DateTime.now();
      int total = 0;
      for (var entry in _cigarettesPerDay.entries) {
        if (!entry.key.isBefore(start) && !entry.key.isAfter(end)) {
          total += entry.value;
        }
      }
      return total;
    }
  }

  DateTime _getPeriodStart() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'week':
        return now.subtract(const Duration(days: 6));
      case 'month':
        return now.subtract(const Duration(days: 29));
      case 'year':
        return now.subtract(const Duration(days: 364));
      case 'all':
        if (_cigarettesPerDay.isEmpty) return now;
        return _cigarettesPerDay.keys.reduce((a, b) => a.isBefore(b) ? a : b);
      default:
        return now;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDay = _selectedPeriod == 'day';
    final spots = isDay ? _buildHourlySpots() : _buildDailySpots();
    final maxY = _getMaxY(spots);
    final labels = isDay
        ? List.generate(24, (h) => '$h:00')
        : _getDailyLabels();
    final replacements = _countReplacements();
    final cigarettes = _countCigarettes();
    final relapses = _journalEntries
        .where((e) => e['type'] == 'relapse')
        .length; // общее количество срывов (можно тоже фильтровать, но оставим пока)
    final successRate = (replacements + cigarettes) > 0
        ? (replacements / (replacements + cigarettes) * 100).round()
        : 0;

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
            // Выбор периода
            Wrap(
              spacing: 8,
              children: [
                _buildPeriodChip('День', 'day'),
                _buildPeriodChip('Неделя', 'week'),
                _buildPeriodChip('Месяц', 'month'),
                _buildPeriodChip('Год', 'year'),
                _buildPeriodChip('Всё время', 'all'),
              ],
            ),
            // Навигация по дням для режима "День"
            if (isDay)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: AppColors.primary),
                      onPressed: () {
                        if (_selectedDay != null) {
                          setState(() {
                            _selectedDay = _selectedDay!.subtract(const Duration(days: 1));
                          });
                        }
                      },
                    ),
                    Text(
                      _selectedDay != null
                          ? '${_selectedDay!.day}.${_selectedDay!.month}.${_selectedDay!.year}'
                          : 'Сегодня',
                      style: const TextStyle(color: AppColors.text, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: AppColors.primary),
                      onPressed: () {
                        if (_selectedDay != null) {
                          final next = _selectedDay!.add(const Duration(days: 1));
                          if (!next.isAfter(DateTime.now())) {
                            setState(() {
                              _selectedDay = next;
                            });
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            // График
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
                          lineTouchData: LineTouchData(
                            touchCallback: (event, response) {
                              if (!isDay && response?.lineBarSpots != null && response!.lineBarSpots!.isNotEmpty) {
                                final spot = response.lineBarSpots!.first;
                                final date = _getDateByIndex(spot.x.toInt());
                                if (date != null) {
                                  setState(() {
                                    _selectedPeriod = 'day';
                                    _selectedDay = date;
                                  });
                                }
                              }
                            },
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems: (spots) {
                                return spots.map((spot) {
                                  final label = isDay
                                      ? '${spot.x.toInt()}:00'
                                      : _getDailyLabels()[spot.x.toInt()];
                                  return LineTooltipItem(
                                    '$label\n${spot.y.toInt()} сиг.',
                                    const TextStyle(color: Colors.white, fontSize: 12),
                                  );
                                }).toList();
                              },
                            ),
                          ),
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
            // Информационные панели
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(Icons.self_improvement, AppColors.success, replacements.toString(), 'Замены'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(Icons.smoking_rooms, AppColors.warning, cigarettes.toString(), 'Сигареты'),
                ),
              ],
            ),
            if (relapses > 0) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Из них срывов: $relapses',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
            if ((replacements + cigarettes) > 0) ...[
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

  Widget _buildPeriodChip(String label, String period) {
    final selected = _selectedPeriod == period;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() {
        _selectedPeriod = period;
        if (period == 'day' && _selectedDay == null) {
          _selectedDay = DateTime.now();
        }
      }),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.text),
    );
  }

  Widget _buildInfoCard(IconData icon, Color color, String value, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  double _getMaxY(List<FlSpot> spots) {
    double max = 0;
    for (var spot in spots) {
      if (spot.y > max) max = spot.y;
    }
    return max + 2;
  }
}