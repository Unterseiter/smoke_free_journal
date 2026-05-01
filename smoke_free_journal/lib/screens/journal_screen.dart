import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../config/app_colors.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  Box _box = Hive.box('smokingData');
  List<Map<String, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  void _loadEntries() {
    final stored = _box.get('journalEntries');
    if (stored != null) {
      final decoded = jsonDecode(stored) as List<dynamic>;
      setState(() {
        _entries = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    }
  }

  Future<void> _saveEntries() async {
    final encoded = jsonEncode(_entries);
    await _box.put('journalEntries', encoded);
    await _box.flush();
  }

  Future<void> _addEntry(String type, String content) async {
    final title = content.trim().split('\n').first.isEmpty
        ? 'Без названия'
        : content.trim().split('\n').first;
    final entry = {
      'date': DateTime.now().toIso8601String(),
      'type': type,
      'content': content,
      'title': title,
    };
    setState(() {
      _entries.insert(0, entry);
    });
    await _saveEntries();

    if (type == 'relapse') {
      await _incrementCigarettesForToday();
    }
  }

  Future<void> _incrementCigarettesForToday() async {
    final storedMap = _box.get('cigarettesPerDay');
    Map<String, int> cigarettesMap = {};
    if (storedMap != null) {
      final decoded = jsonDecode(storedMap) as Map<String, dynamic>;
      decoded.forEach((key, value) {
        cigarettesMap[key] = value as int;
      });
    }
    final todayKey = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    cigarettesMap.update(todayKey, (count) => count + 1, ifAbsent: () => 1);
    await _box.put('cigarettesPerDay', jsonEncode(cigarettesMap));
    await _box.flush();
  }

  void _showAddDialog() {
    String selectedType = 'note';
    TextEditingController textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Новая заметка', style: TextStyle(color: AppColors.text)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setDialogState(() => selectedType = 'trigger'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedType == 'trigger' ? AppColors.success.withOpacity(0.8) : AppColors.surface,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Триггер'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setDialogState(() => selectedType = 'relapse'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedType == 'relapse' ? AppColors.warning.withOpacity(0.8) : AppColors.surface,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Срыв'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setDialogState(() => selectedType = 'note'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedType == 'note' ? AppColors.primary.withOpacity(0.8) : AppColors.surface,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Заметка'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 5,
                style: const TextStyle(color: AppColors.text),
                decoration: const InputDecoration(
                  hintText: 'Текст в формате Markdown...',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
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
                  _addEntry(selectedType, content);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final containerWidth = screenWidth - 32;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Журнал'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: containerWidth,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
              borderRadius: BorderRadius.circular(12),
              color: AppColors.surface,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}',
                  style: const TextStyle(fontSize: 16, color: AppColors.text),
                ),
                Text(
                  'Записей: ${_entries.length}',
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _entries.isEmpty
                ? const Center(
                    child: Text('Записей пока нет', style: TextStyle(color: AppColors.textSecondary)),
                  )
                : ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      final title = entry['title'] ?? 'Без названия';
                      final type = entry['type'] ?? 'note';

                      Color borderColor;
                      IconData icon;
                      String typeLabel;
                      if (type == 'trigger') {
                        borderColor = AppColors.success;
                        icon = Icons.self_improvement;
                        typeLabel = 'Триггер';
                      } else if (type == 'relapse') {
                        borderColor = AppColors.warning;
                        icon = Icons.smoking_rooms;
                        typeLabel = 'Срыв';
                      } else {
                        borderColor = AppColors.primary;
                        icon = Icons.note;
                        typeLabel = 'Заметка';
                      }

                      return Card(
                        color: AppColors.surface,
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: borderColor, width: 2),
                        ),
                        child: ListTile(
                          leading: Icon(icon, color: borderColor),
                          title: Text(title, style: TextStyle(color: borderColor, fontWeight: FontWeight.bold)),
                          subtitle: Text(typeLabel, style: const TextStyle(color: AppColors.textSecondary)),
                          onTap: () => _showViewDialog(entry),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showViewDialog(Map<String, dynamic> entry) {
    final type = entry['type'] ?? 'note';
    final content = entry['content'] ?? '';
    final date = DateTime.parse(entry['date']);
    final formattedDate = '${date.hour}:${date.minute.toString().padLeft(2, '0')}, ${date.day}.${date.month}.${date.year}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(
              type == 'trigger' ? Icons.self_improvement : (type == 'relapse' ? Icons.smoking_rooms : Icons.note),
              color: type == 'trigger' ? AppColors.success : (type == 'relapse' ? AppColors.warning : AppColors.primary),
            ),
            const SizedBox(width: 8),
            Text(
              type == 'trigger' ? 'Триггер' : (type == 'relapse' ? 'Срыв' : 'Заметка'),
              style: TextStyle(color: AppColors.text),
            ),
            const Spacer(),
            Text(formattedDate, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        content: SingleChildScrollView(
          child: MarkdownBody(
            data: content,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(color: AppColors.text),
              h1: const TextStyle(color: AppColors.primary),
              h2: const TextStyle(color: AppColors.primary),
              strong: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
} 