import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:mingym/models/gym_models.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String usersCol = 'users';
  static const String routinesCol = 'routines';
  static const String historyCol = 'history';
  static const String latestStatsCol = 'latest_stats';
  static const String bodyWeightCol = 'bodyweight';
  static const String customExCol = 'custom_exercises';
  static const String defaultExCol = 'default_exercises';

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<Routine>> getRoutinesStream() {
    final uid = _userId;
    if (uid == null) return Stream.value([]); 

    return _db
        .collection(usersCol)
        .doc(uid)
        .collection(routinesCol)
        .orderBy('sortIndex')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Routine.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> saveRoutine(Routine routine) async {
    final uid = _userId;
    if (uid == null) throw Exception("User not logged in");

    try {
      final docRef = routine.id.isEmpty 
          ? _db.collection(usersCol).doc(uid).collection(routinesCol).doc()
          : _db.collection(usersCol).doc(uid).collection(routinesCol).doc(routine.id);

      await docRef.set({
        'title': routine.title,
        'exercises': routine.exercises.map((e) => e.toMap()).toList(),
        'sortIndex': routine.sortIndex,
      }, SetOptions(merge: true));
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Error saving routine');
      rethrow;
    }
  }
  
  Future<void> updateRoutineOrder(List<Routine> routines) async {
    final uid = _userId;
    if (uid == null) return;

    try {
      final batch = _db.batch();
      for (int i = 0; i < routines.length; i++) {
        final docRef = _db.collection(usersCol).doc(uid).collection(routinesCol).doc(routines[i].id);
        batch.set(docRef, {'sortIndex': i}, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Error updating routine order');
      rethrow;
    }
  }

  Stream<List<WorkoutLog>> getWorkoutHistoryStream() {
    final uid = _userId;
    if (uid == null) return Stream.value([]); 

    return _db
        .collection(usersCol)
        .doc(uid)
        .collection(historyCol)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WorkoutLog.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> saveWorkoutLog(WorkoutLog log) async {
    final uid = _userId;
    if (uid == null) throw Exception("User not logged in");

    try {
      final docRef = _db.collection(usersCol).doc(uid).collection(historyCol).doc();
      await docRef.set(log.toMap());
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Error saving workout log');
      rethrow;
    }
  }

  Future<void> saveWorkout({
    String? id, 
    required String title,
    required double totalVolume,
    required int durationMinutes,
    required List<Map<String, dynamic>> exercises,
  }) async {
    final uid = _userId;
    if (uid == null) throw Exception("User not logged in");

    try {
      final historyRef = _db.collection(usersCol).doc(uid).collection(historyCol);
      final latestStatsRef = _db.collection(usersCol).doc(uid).collection(latestStatsCol);

      if (id != null && id.isNotEmpty) {
        await historyRef.doc(id).update({
          'title': title,
          'totalVolume': totalVolume,
          'durationMinutes': durationMinutes,
          'exercises': exercises,
        });
      } else {
        await historyRef.add({
          'title': title,
          'totalVolume': totalVolume,
          'durationMinutes': durationMinutes,
          'date': Timestamp.now(), 
          'exercises': exercises,
        });
      }

      for (var exercise in exercises) {
        final exerciseName = exercise['name'];
        final sets = exercise['sets'];

        await latestStatsRef.doc(exerciseName).set({
          'lastPerformed': Timestamp.now(),
          'sets': sets,
        }, SetOptions(merge: true)); 
      }
      
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Error saving workout');
      rethrow;
    }
  }
  
  Future<void> deleteWorkout(String id) async {
    final uid = _userId;
    if (uid == null) throw Exception("User not logged in");

    try {
      final historyRef = _db.collection(usersCol).doc(uid).collection(historyCol);
      final latestStatsRef = _db.collection(usersCol).doc(uid).collection(latestStatsCol);
      final docSnapshot = await historyRef.doc(id).get();
      if (!docSnapshot.exists) return;

      final workoutData = docSnapshot.data()!;
      final exercises = workoutData['exercises'] as List<dynamic>? ?? [];

      await historyRef.doc(id).delete();

      for (var ex in exercises) {
        final exerciseName = ex['name'] as String;
        final recentWorkouts = await historyRef.orderBy('date', descending: true).limit(30).get();

        bool foundPrevious = false;
        for (var recentDoc in recentWorkouts.docs) {
          final recentData = recentDoc.data();
          final recentExercises = recentData['exercises'] as List<dynamic>? ?? [];
          final pastExercise = recentExercises.firstWhere(
            (e) => e['name'] == exerciseName,
            orElse: () => null,
          );

          if (pastExercise != null && pastExercise['sets'] != null) {
            await latestStatsRef.doc(exerciseName).set({
              'lastPerformed': recentData['date'],
              'sets': pastExercise['sets'],
            }, SetOptions(merge: true));
            foundPrevious = true;
            break; 
          }
        }

        if (!foundPrevious) {
          await latestStatsRef.doc(exerciseName).delete();
        }
      }
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Error deleting workout');
      rethrow;
    }
  }

  Future<void> deleteRoutine(String id) async {
    final uid = _userId;
    if (uid == null) throw Exception("User not logged in");

    try {
      await _db.collection(usersCol).doc(uid).collection(routinesCol).doc(id).delete();
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Error deleting routine');
      rethrow;
    }
  }
  
  Future<List<WorkoutSet>> getLastExerciseStats(String exerciseName) async {
    final uid = _userId;
    if (uid == null) return [];

    try {
      final doc = await _db.collection(usersCol).doc(uid).collection(latestStatsCol).doc(exerciseName).get();
      
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['sets'] != null) {
          final setsList = data['sets'] as List;
          return setsList.map((x) => WorkoutSet.fromMap(x as Map<String, dynamic>)).toList();
        }
      }
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Error getting past stats for $exerciseName');
    }
    return [];
  }

  Future<void> logBodyWeight(double weight) async {
    final uid = _userId;
    if (uid == null) throw Exception("User not logged in");

    try {
      await _db.collection(usersCol).doc(uid).collection(bodyWeightCol).add({
        'date': FieldValue.serverTimestamp(),
        'weight': weight,
      });
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Error logging bodyweight');
      rethrow;
    }
  }

  Stream<List<BodyWeightLog>> getBodyWeightHistoryStream() {
    final uid = _userId;
    if (uid == null) return Stream.value([]); 

    return _db
        .collection(usersCol)
        .doc(uid)
        .collection(bodyWeightCol)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BodyWeightLog.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Future<void> saveCustomExercise(Map<String, dynamic> exerciseData) async {
    final uid = _userId;
    if (uid == null) throw Exception("User not logged in");

    try {
      await _db.collection(usersCol).doc(uid).collection(customExCol).add(exerciseData);
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Error saving custom exercise');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> getCustomExercisesStream() {
    final uid = _userId;
    if (uid == null) return Stream.value([]);

    return _db
        .collection(usersCol)
        .doc(uid)
        .collection(customExCol)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<List<Map<String, dynamic>>> getDefaultExercises() async {
    try {
      final snapshot = await _db.collection(defaultExCol).get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Error getting default exercises');
      return [];
    }
  }
}