import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:mingym/models/gym_models.dart';
import 'package:mingym/services/firestore_service.dart';
import 'package:mingym/services/notification_service.dart';

class ActiveWorkoutManager extends ChangeNotifier {
  static final ActiveWorkoutManager _instance = ActiveWorkoutManager._internal();
  factory ActiveWorkoutManager() => _instance;
  ActiveWorkoutManager._internal() {
    _loadSettings(); 
  }

  bool isActive = false;
  bool isEditing = false;
  WorkoutLog? editLog;

  String workoutTitle = 'Workout';
  int elapsedSeconds = 0;
  int restSeconds = 120; 
  int defaultRestSeconds = 120; 
  bool isRestTimerRunning = false; 
  List<Map<String, dynamic>> activeExercises = [];
  
  bool isKg = true; 
  String get unitString => isKg ? 'kg' : 'lbs';

  Timer? _workoutTimer;
  Timer? _restTimer;

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    defaultRestSeconds = prefs.getInt('default_rest_time') ?? 120;
    isKg = prefs.getBool('use_kg') ?? true; 
    restSeconds = defaultRestSeconds; 
    notifyListeners();
  }
  
  void startWorkout({Routine? routine}) async {
    if (isActive) return;

    isActive = true;
    isEditing = false;
    editLog = null;
    elapsedSeconds = 0;
    restSeconds = defaultRestSeconds;
    isRestTimerRunning = false;

    final hour = DateTime.now().hour;
    workoutTitle = hour < 12 ? 'Morning Workout' : hour < 17 ? 'Afternoon Workout' : 'Evening Workout';
    activeExercises = [];

    _startWorkoutTimer();
    notifyListeners(); 

    if (routine != null) {
      workoutTitle = routine.title;
      for (var ex in routine.exercises) {
        await addExercise(ex.name, defaultSets: ex.sets);
      }
    }
  }

  void startEditWorkout(WorkoutLog log) {
    if (isActive) return;

    isActive = true;
    isEditing = true;
    editLog = log;
    workoutTitle = log.title;
    elapsedSeconds = log.durationMinutes * 60;
    restSeconds = 0;

    activeExercises = log.exercises.map<Map<String, dynamic>>((ex) {
      return {
        'name': ex.name,
        'history': <WorkoutSet>[],
        'sets': ex.loggedSets.map<Map<String, dynamic>>((set) => {
          'weight': set.weight == 0 ? '' : getDisplayWeight(set.weight).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
          'reps': set.reps == 0 ? '' : set.reps.toString(),
          'rpe': set.rpe?.toString() ?? '',
          'prevWeight': '-', 'prevReps': '-', 'prevRpe': '-',
          'isCompleted': set.isCompleted,
        }).toList(),
      };
    }).toList();

    notifyListeners();
  }

  void _startWorkoutTimer() {
    _workoutTimer?.cancel(); 
    
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      elapsedSeconds++;
      notifyListeners();
    });
  }

  void startRestTimer() {
    _restTimer?.cancel();
    restSeconds = defaultRestSeconds;
    isRestTimerRunning = true;
    notifyListeners();
    
    NotificationService().showRestTimer(
      durationSeconds: restSeconds, 
    );
    
    _runRestTimer();
  }

  void _runRestTimer() {
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (restSeconds > 0) {
        restSeconds--;
        notifyListeners();
      } else {
        _restTimer?.cancel();
        isRestTimerRunning = false;
        restSeconds = defaultRestSeconds; 
        
        NotificationService().cancelRestTimer();
        notifyListeners();
      }
    });
  }

  void toggleRestTimer() {
    if (isRestTimerRunning) {
      _restTimer?.cancel();
      isRestTimerRunning = false;
      NotificationService().cancelRestTimer();
    } else {
      if (restSeconds <= 0) restSeconds = defaultRestSeconds;
      isRestTimerRunning = true;
      
      NotificationService().showRestTimer(
        durationSeconds: restSeconds, 
      );
      
      _runRestTimer();
    }
    notifyListeners();
  }

  void adjustRestTime(int seconds) {
    restSeconds += seconds;
    if (restSeconds <= 0) {
      restSeconds = 0;
      _restTimer?.cancel();
      isRestTimerRunning = false;
      NotificationService().cancelRestTimer();
    } else if (isRestTimerRunning) {
      NotificationService().showRestTimer(
        durationSeconds: restSeconds, 
      );
    }
    notifyListeners();
  }

  void skipRest() {
    _restTimer?.cancel();
    isRestTimerRunning = false;
    restSeconds = defaultRestSeconds;
    
    NotificationService().cancelRestTimer();
    notifyListeners();
  }
  
  bool isAllSetsCompleted() {
    if (activeExercises.isEmpty) return false;
    
    for (var exercise in activeExercises) {
      for (var set in exercise['sets']) {
        if (set['isCompleted'] == false) {
          return false;
        }
      }
    }
    return true;
  }

  Future<void> finishWorkout() async {
    _workoutTimer?.cancel();
    _restTimer?.cancel();

    double totalVolume = 0;
    List<Map<String, dynamic>> completedExercises = [];

    for (var exercise in activeExercises) {
      List<Map<String, dynamic>> completedSets = [];
      for (var set in exercise['sets']) {
        if (set['isCompleted'] == true) {
          double inputWeight = double.tryParse(set['weight'].toString()) ?? 0.0;
          double dbWeight = getDatabaseWeight(inputWeight); 
          int reps = int.tryParse(set['reps'].toString()) ?? 0;
          int? rpe = int.tryParse(set['rpe'].toString());
          
          totalVolume += (dbWeight * reps);
          completedSets.add({
            'weight': dbWeight, 'reps': reps, 'rpe': rpe, 'isCompleted': true,
          });
        }
      }
      if (completedSets.isNotEmpty) {
        completedExercises.add({'name': exercise['name'], 'sets': completedSets});
      }
    }

    int durationMinutes = isEditing ? editLog!.durationMinutes : (elapsedSeconds / 60).floor();

    try {
      await FirestoreService().saveWorkout(
        id: editLog?.id, 
        title: workoutTitle.trim().isEmpty ? 'Workout' : workoutTitle.trim(), 
        totalVolume: totalVolume,
        durationMinutes: durationMinutes,
        exercises: completedExercises,
      );
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Background sync error during finishWorkout');
    }
    
    _clearSession();
  }
  
  Future<void> addExercise(String name, {int defaultSets = 1}) async {
    List<WorkoutSet> prevSets = [];
    try {
      prevSets = await FirestoreService().getLastExerciseStats(name);
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Failed to fetch previous sets for $name');
    }

    List<Map<String, dynamic>> newSets = [];
    for (int i = 0; i < defaultSets; i++) {
      String pWeight = '-';
      String pReps = '-';
      String pRpe = '-';

      if (i < prevSets.length) {
        pWeight = prevSets[i].weight > 0 ? getDisplayWeight(prevSets[i].weight).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '') : '-';
        pReps = prevSets[i].reps > 0 ? prevSets[i].reps.toString() : '-';
        pRpe = prevSets[i].rpe != null ? prevSets[i].rpe.toString() : '-';
      }

      newSets.add({
        'weight': '', 'reps': '', 'rpe': '',
        'prevWeight': pWeight, 'prevReps': pReps, 'prevRpe': pRpe,
        'isCompleted': false
      });
    }
    
    activeExercises.add({
      'name': name, 
      'history': prevSets, 
      'sets': newSets
    });
    notifyListeners();
  }

  void addSetToExercise(int exerciseIndex) {
    final exercise = activeExercises[exerciseIndex];
    final sets = exercise['sets'] as List;
    final history = exercise['history'] as List<WorkoutSet>? ?? [];
    
    final targetIndex = sets.length;
    
    String pWeight = '-';
    String pReps = '-';
    String pRpe = '-';

    if (targetIndex < history.length) {
      pWeight = history[targetIndex].weight > 0 ? getDisplayWeight(history[targetIndex].weight).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '') : '-';
      pReps = history[targetIndex].reps > 0 ? history[targetIndex].reps.toString() : '-';
      pRpe = history[targetIndex].rpe != null ? history[targetIndex].rpe.toString() : '-';
    }

    sets.add({
      'weight': '', 'reps': '', 'rpe': '',
      'prevWeight': pWeight, 'prevReps': pReps, 'prevRpe': pRpe,
      'isCompleted': false
    });
    notifyListeners();
  }
  
  void cancelWorkout() {
    _clearSession();
  }

  void _clearSession() {
    _workoutTimer?.cancel();
    _restTimer?.cancel();
    isActive = false;
    isEditing = false;
    isRestTimerRunning = false;
    editLog = null;
    activeExercises = [];
    elapsedSeconds = 0;
    restSeconds = defaultRestSeconds;
    NotificationService().cancelRestTimer();
    notifyListeners();
  }
  
  double getDisplayWeight(double kgWeight) {
    if (kgWeight == 0) return 0;
    return isKg ? kgWeight : (kgWeight * 2.20462);
  }

  double getDatabaseWeight(double uiWeight) {
    if (uiWeight == 0) return 0;
    return isKg ? uiWeight : (uiWeight / 2.20462);
  }

  void updateUI() {
    notifyListeners();
  }
}