import 'package:flutter/material.dart';
import 'package:mingym/models/gym_models.dart';
import 'package:mingym/services/firestore_service.dart';
import 'package:mingym/screens/active_workout_screen.dart';
import 'package:mingym/screens/routine_editor_screen.dart';
import 'package:mingym/managers/active_workout_manager.dart';
import 'package:mingym/widgets/workout_history_card.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  final FirestoreService _firestore = FirestoreService();

  late Stream<List<Routine>> _routinesStream;
  late Stream<List<WorkoutLog>> _historyStream;

  @override
  void initState() {
    super.initState();
    _routinesStream = _firestore.getRoutinesStream();
    _historyStream = _firestore.getWorkoutHistoryStream();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Never';
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '$diff days ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Routine>>(
        stream: _routinesStream,
        builder: (context, routineSnapshot) {
          return StreamBuilder<List<WorkoutLog>>(
            stream: _historyStream,
            builder: (context, historySnapshot) {
              
              if (routineSnapshot.connectionState == ConnectionState.waiting ||
                  historySnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final List<Routine> routines = List.from(routineSnapshot.data ?? []);
              final history = historySnapshot.data ?? [];

              return Column(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 48, 16, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Saved Routines', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const RoutineEditorScreen()));
                                },
                                icon: const Icon(Icons.add, size: 18, color: Colors.blueAccent),
                                label: const Text('New', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                              )
                            ],
                          ),
                        ),
                        
                        Expanded(
                          child: routines.isEmpty 
                            ? const Center(child: Text('No routines saved yet.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)))
                            : Theme(
                                data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
                                child: ReorderableListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  itemCount: routines.length,
                                  proxyDecorator: (Widget child, int index, Animation<double> animation) {
                                    return AnimatedBuilder(
                                      animation: animation,
                                      builder: (BuildContext context, Widget? child) {
                                        return Material(
                                          color: Colors.transparent,
                                          elevation: 0,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.6 * animation.value), 
                                                  blurRadius: 4 * animation.value,
                                                  spreadRadius: animation.value,
                                                  offset: Offset(0, 1.5 * animation.value),
                                                )
                                              ],
                                            ),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: child,
                                    );
                                  },
                                  onReorder: (int oldIndex, int newIndex) {
                                    setState(() {
                                      if (oldIndex < newIndex) {
                                        newIndex -= 1;
                                      }
                                      final item = routines.removeAt(oldIndex);
                                      routines.insert(newIndex, item);
                                    });
                                    _firestore.updateRoutineOrder(routines);
                                  },
                                  itemBuilder: (context, index) {
                                    final routine = routines[index];
                                    return Card(
                                      key: ValueKey(routine.id),
                                      color: Colors.grey.shade900,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.only(left: 16, right: 8),
                                        title: Text(
                                          '${routine.title} - ${routine.exercises.length} Exercises', 
                                          style: const TextStyle(fontWeight: FontWeight.bold)
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.play_circle_fill, color: Colors.green, size: 32),
                                              onPressed: () {
                                                if (ActiveWorkoutManager().isActive) {
                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please finish your current workout first!'), backgroundColor: Colors.redAccent));
                                                  return;
                                                }
                                                ActiveWorkoutManager().startWorkout(routine: routine);
                                                Navigator.push(context, MaterialPageRoute(builder: (context) => const ActiveWorkoutScreen()));
                                              },
                                            ),
                                            PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_vert, color: Colors.grey),
                                              color: Colors.grey.shade800,
                                              onSelected: (value) {
                                                if (value == 'edit') {
                                                  Navigator.push(context, MaterialPageRoute(builder: (context) => RoutineEditorScreen(editRoutine: routine)));
                                                } else if (value == 'delete') {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      backgroundColor: Colors.grey.shade900,
                                                      title: const Text('Delete Routine', style: TextStyle(color: Colors.white)),
                                                      content: const Text('Are you sure you want to delete this routine? This cannot be undone.', style: TextStyle(color: Colors.white70)),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                                                        TextButton(
                                                          onPressed: () {
                                                            _firestore.deleteRoutine(routine.id);
                                                            Navigator.pop(context);
                                                          },
                                                          child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.white, size: 18), SizedBox(width: 8), Text('Edit', style: TextStyle(color: Colors.white))])),
                                                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.redAccent, size: 18), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.redAccent))])),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.white12, height: 1, thickness: 1),
                  
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Recent Workouts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ListenableBuilder(
                                listenable: ActiveWorkoutManager(),
                                builder: (context, child) {
                                  if (ActiveWorkoutManager().isActive) return const SizedBox();
                                  return TextButton.icon(
                                    onPressed: () {
                                      ActiveWorkoutManager().startWorkout();
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ActiveWorkoutScreen()));
                                    },
                                    icon: const Icon(Icons.add, color: Colors.blueAccent, size: 18),
                                    label: const Text('New', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListenableBuilder(
                            listenable: ActiveWorkoutManager(),
                            builder: (context, child) {
                              final manager = ActiveWorkoutManager();
                              final isActive = manager.isActive;
                              final displayCount = history.length + (isActive ? 1 : 0);

                              if (displayCount == 0) {
                                return const Center(child: Text('No workout history found.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)));
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                itemCount: displayCount,
                                itemBuilder: (context, index) {
                                  bool isLiveItem = isActive && index == 0;
                                  final logData = isLiveItem ? null : history[isActive ? index - 1 : index];
                                  final String title = isLiveItem ? manager.workoutTitle : logData!.title;
                                  final String dateText = isLiveItem ? "Running Now" : _formatDate(logData!.date);
                                  
                                  double rawVol = 0;
                                  int duration = 0;
                                  List<String> exercises = [];

                                  if (isLiveItem) {
                                    duration = (manager.elapsedSeconds / 60).floor();
                                    for (var ex in manager.activeExercises) {
                                      final sets = ex['sets'] as List;
                                      int completedCount = 0;
                                      for (var s in sets) {
                                        if (s['isCompleted'] == true) {
                                          double w = double.tryParse(s['weight'].toString()) ?? 0;
                                          int r = int.tryParse(s['reps'].toString()) ?? 0;
                                          rawVol += (w * r);
                                          completedCount++;
                                        }
                                      }
                                      exercises.add('$completedCount/${sets.length}x ${ex['name']}');
                                    }
                                  } else {
                                    rawVol = logData!.totalVolume;
                                    duration = logData.durationMinutes;
                                    exercises = logData.exercises.map((e) => '${e.sets}x ${e.name}').toList();
                                  }

                                  return WorkoutHistoryCard(
                                    title: title,
                                    dateText: dateText,
                                    displayVol: manager.getDisplayWeight(rawVol),
                                    unitString: manager.unitString,
                                    duration: duration,
                                    exerciseText: exercises.join('\n'),
                                    isLive: isLiveItem,
                                    onResume: () => Navigator.push(
                                      context, 
                                      MaterialPageRoute(builder: (context) => const ActiveWorkoutScreen())
                                    ),
                                    onMenuSelected: (value) {
                                      if (value == 'edit') {
                                        if (ActiveWorkoutManager().isActive) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Please finish your current workout first!'), backgroundColor: Colors.redAccent)
                                          );
                                          return;
                                        }
                                        ActiveWorkoutManager().startEditWorkout(logData!);
                                        Navigator.push(
                                          context, 
                                          MaterialPageRoute(builder: (context) => const ActiveWorkoutScreen())
                                        );
                                      } else if (value == 'delete') {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            backgroundColor: Colors.grey.shade900,
                                            title: const Text('Delete Workout', style: TextStyle(color: Colors.white)),
                                            content: const Text('Are you sure you want to delete this workout? This cannot be undone.', style: TextStyle(color: Colors.white70)),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context), 
                                                child: const Text('Cancel', style: TextStyle(color: Colors.grey))
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  _firestore.deleteWorkout(logData!.id);
                                                  Navigator.pop(context);
                                                },
                                                child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
          );
        }
      ),
    );
  }
}
