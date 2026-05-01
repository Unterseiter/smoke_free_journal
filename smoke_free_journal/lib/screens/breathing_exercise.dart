import 'dart:async';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class BreathingExerciseScreen extends StatefulWidget {
  const BreathingExerciseScreen({super.key});

  @override
  State<BreathingExerciseScreen> createState() => _BreathingExerciseScreenState();
}

class _BreathingExerciseScreenState extends State<BreathingExerciseScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _secondsLeft = 60;
  Timer? _timer;
  String _phase = 'Приготовьтесь...';
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 8), // полный цикл 4+4
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller)
      ..addListener(() {
        setState(() {});
      });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _phase = 'Выдох';
        });
      } else if (status == AnimationStatus.dismissed) {
        setState(() {
          _phase = 'Вдох';
        });
      }
    });

    _startExercise();
  }

  void _startExercise() {
    _isRunning = true;
    _phase = 'Вдох';
    _controller.forward(from: 0.0); // начинаем с вдоха

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
        });
        // управляем фазами: 4 сек вдох, 4 сек выдох
        if (_secondsLeft % 8 == 0) {
          _phase = 'Вдох';
          _controller.forward(from: 0.0);
        } else if (_secondsLeft % 8 == 4) {
          _phase = 'Выдох';
          _controller.reverse(from: 1.0);
        }
      } else {
        _timer?.cancel();
        setState(() {
          _isRunning = false;
          _phase = 'Готово!';
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final circleSize = 100.0 + (_animation.value * 100.0); // от 100 до 200

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('SOS Дыхание'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.7),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _phase,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              '${_secondsLeft} секунд',
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 40,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _isRunning ? 'Следуйте за кругом' : 'Упражнение завершено',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 40),
            if (!_isRunning)
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Вернуться'),
              ),
          ],
        ),
      ),
    );
  }
}