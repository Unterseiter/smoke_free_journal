// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'smoking_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SmokingDayAdapter extends TypeAdapter<SmokingDay> {
  @override
  final int typeId = 0;

  @override
  SmokingDay read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SmokingDay(
      date: fields[0] as DateTime,
      count: fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SmokingDay obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.count);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmokingDayAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SmokingDataAdapter extends TypeAdapter<SmokingData> {
  @override
  final int typeId = 1;

  @override
  SmokingData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SmokingData(
      cigarettesPerDay: (fields[0] as Map).cast<String, int>(),
      lastSmokeTime: fields[1] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, SmokingData obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.cigarettesPerDay)
      ..writeByte(1)
      ..write(obj.lastSmokeTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmokingDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
