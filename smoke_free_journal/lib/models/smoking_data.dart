import 'package:hive/hive.dart';

part 'smoking_data.g.dart';

@HiveType(typeId: 0)
class SmokingDay extends HiveObject {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final int count;

  SmokingDay({required this.date, required this.count});
}

@HiveType(typeId: 1)
class SmokingData extends HiveObject {
  @HiveField(0)
  Map<String, int> cigarettesPerDay;

  @HiveField(1)
  DateTime? lastSmokeTime;

  SmokingData({required this.cigarettesPerDay, this.lastSmokeTime});
}