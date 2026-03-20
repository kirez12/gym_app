import 'package:cloud_firestore/cloud_firestore.dart';

class WorkoutSet {
  double weight;
  int reps;
  int? rpe;
  bool isCompleted;

  WorkoutSet({
    required this.weight, 
    required this.reps, 
    this.rpe,
    this.isCompleted = true, 
  });

  Map<String, dynamic> toMap() {
    return {
      'weight': weight,
      'reps': reps,
      'rpe': rpe,
      'isCompleted': isCompleted,
    };
  }

  factory WorkoutSet.fromMap(Map<String, dynamic> map) {
    return WorkoutSet(
      weight: (map['weight'] ?? 0).toDouble(),
      reps: map['reps']?.toInt() ?? 0,
      rpe: map['rpe']?.toInt(),
      isCompleted: map['isCompleted'] ?? true,
    );
  }
}

class Exercise {
  final String name;
  final int sets;
  final List<WorkoutSet> loggedSets;

  Exercise({
    required this.name, 
    required this.sets, 
    this.loggedSets = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sets': loggedSets.isNotEmpty ? loggedSets.map((s) => s.toMap()).toList() : sets,
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    int parsedSetCount = 0;
    List<WorkoutSet> parsedLoggedSets = [];

    if (map['sets'] is List) {
      final list = map['sets'] as List;
      parsedSetCount = list.length;
      parsedLoggedSets = list.map((x) => WorkoutSet.fromMap(x as Map<String, dynamic>)).toList();
    } else if (map['sets'] is num) {
      parsedSetCount = (map['sets'] as num).toInt();
    }

    return Exercise(
      name: map['name'] ?? 'Unknown Exercise',
      sets: parsedSetCount,
      loggedSets: parsedLoggedSets,
    );
  }
}

class Routine {
  final String id;
  final String title;
  final List<Exercise> exercises;
  final int sortIndex;

  Routine({
    required this.id,
    required this.title,
    required this.exercises,
    this.sortIndex = 0,
  });

  factory Routine.fromMap(Map<String, dynamic> data, String documentId) {
    return Routine(
      id: documentId,
      title: data['title'] ?? '',
      exercises: (data['exercises'] as List?)?.map((e) => Exercise.fromMap(e)).toList() ?? [],
      sortIndex: data['sortIndex'] ?? 0,
    );
  }
}
class WorkoutLog {
  final String id;
  final String title;
  final DateTime date;
  final int durationMinutes;
  final double totalVolume;
  final List<Exercise> exercises;

  WorkoutLog({
    required this.id,
    required this.title,
    required this.date,
    required this.durationMinutes,
    required this.totalVolume,
    required this.exercises,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'date': Timestamp.fromDate(date),
      'durationMinutes': durationMinutes,
      'totalVolume': totalVolume,
      'exercises': exercises.map((e) => e.toMap()).toList(),
    };
  }

  factory WorkoutLog.fromMap(Map<String, dynamic> map, String documentId) {
    return WorkoutLog(
      id: documentId,
      title: map['title'] ?? 'Unknown Workout',
      date: map['date'] != null ? (map['date'] as Timestamp).toDate() : DateTime.now(),
      durationMinutes: map['durationMinutes']?.toInt() ?? 0,
      totalVolume: (map['totalVolume'] ?? 0).toDouble(),
      exercises: List<Exercise>.from((map['exercises'] ?? []).map((x) => Exercise.fromMap(x))),
    );
  }
}

class BodyWeightLog {
  final String id;
  final DateTime date;
  final double weight;

  BodyWeightLog({required this.id, required this.date, required this.weight});

  factory BodyWeightLog.fromFirestore(Map<String, dynamic> data, String id) {
    return BodyWeightLog(
      id: id,
      date: (data['date'] as Timestamp).toDate(),
      weight: (data['weight'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'weight': weight,
    };
  }
}