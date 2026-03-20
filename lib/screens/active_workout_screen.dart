import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mingym/managers/active_workout_manager.dart';
import 'package:mingym/screens/exercise_selection_screen.dart';
import 'package:mingym/screens/workout_editor_screen.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  final ActiveWorkoutManager _manager = ActiveWorkoutManager();
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: _manager.workoutTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _manager,
      builder: (context, child) {
        return PopScope(
          canPop: !_manager.isEditing, 
          onPopInvokedWithResult: (bool didPop, Object? result) async {
            if (didPop) return;
            
            if (_manager.isEditing) {
              await _manager.finishWorkout(); 
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Column(
                children: [
                  Text(_manager.isEditing ? 'Edit Workout' : 'Workout in Progress', style: const TextStyle(fontSize: 16)),
                  Text(
                    _formatTime(_manager.elapsedSeconds), 
                    style: TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.bold, 
                      color: _manager.isEditing ? Colors.grey : Colors.blueAccent 
                    )
                  ),
                ],
              ),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () {
                  Navigator.maybePop(context); 
                },
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blueAccent),
                  tooltip: 'Reorder Exercises',
                  onPressed: () async {
                    final updatedExercises = await Navigator.push<List<Map<String, dynamic>>>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkoutEditorScreen(exercises: _manager.activeExercises), 
                      ),
                    );
                    if (updatedExercises != null) {
                      setState(() {
                        _manager.activeExercises = updatedExercises;
                      });
                    }
                  },
                ),
                if (!_manager.isEditing) 
                  TextButton(
                    onPressed: () async {
                      await _manager.finishWorkout();
                      if (context.mounted) Navigator.pop(context);
                    }, 
                    child: const Text('Finish', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          
            bottomNavigationBar: Container(
              height: 90, 
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A), 
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.timer, color: Colors.blueAccent, size: 20),
                          SizedBox(width: 8),
                          Text('Rest', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, color: Colors.white),
                            onPressed: () => _manager.adjustRestTime(-15),
                          ),
                          SizedBox(
                            width: 65,
                            child: Text(
                              _formatTime(_manager.restSeconds),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _manager.restSeconds > 0 ? Colors.white : Colors.grey, 
                                fontSize: 24, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.white),
                            onPressed: () => _manager.adjustRestTime(15),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _manager.isRestTimerRunning ? Icons.pause : Icons.play_arrow, 
                              color: Colors.white
                            ),
                            onPressed: _manager.toggleRestTimer,
                          ),
                          TextButton(
                            onPressed: _manager.skipRest,
                            child: const Text('Skip', style: TextStyle(color: Colors.white70)),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),

            floatingActionButton: SizedBox(
              width: 164,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final selectedExerciseName = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(builder: (context) => const ExerciseSelectionScreen()),
                  );

                  if (selectedExerciseName != null) {
                    _manager.addExercise(selectedExerciseName); 
                  }
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Add Exercise', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: TextField(
                    controller: _titleController,
                    onChanged: (val) => _manager.workoutTitle = val,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Workout Name',
                      hintStyle: TextStyle(color: Colors.white24),
                      border: InputBorder.none,
                      isDense: true,
                      filled: false,
                    ),
                  ),
                ),
                const Divider(color: Colors.white12),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), 
                    itemCount: _manager.activeExercises.length,
                    itemBuilder: (context, index) {
                      final exercise = _manager.activeExercises[index];
                      final sets = exercise['sets'] as List;

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        color: Colors.grey.shade900,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      exercise['name'], 
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                                    color: Colors.grey.shade800,
                                    onSelected: (value) async {
                                      if (value == 'delete') {
                                        _manager.activeExercises.removeAt(index);
                                        _manager.updateUI();
                                      } else if (value == 'replace') {
                                        final newName = await Navigator.push<String>(
                                          context,
                                          MaterialPageRoute(builder: (context) => const ExerciseSelectionScreen()),
                                        );
                                        
                                        if (newName != null) {
                                          exercise['name'] = newName;
                                          _manager.updateUI();
                                        }
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'replace',
                                        child: Row(
                                          children: [
                                            Icon(Icons.swap_horiz, color: Colors.white, size: 18),
                                            SizedBox(width: 8),
                                            Text('Replace Exercise', style: TextStyle(color: Colors.white)),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                            SizedBox(width: 8),
                                            Text('Remove Exercise', style: TextStyle(color: Colors.redAccent)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              Row(
                                children: [
                                  SizedBox(width: 30, child: Text('Set', style: TextStyle(fontWeight: FontWeight.bold))),
                                  Expanded(child: Center(child: Text(_manager.unitString, style: TextStyle(fontWeight: FontWeight.bold)))),
                                  Expanded(child: Center(child: Text('Reps', style: TextStyle(fontWeight: FontWeight.bold)))),
                                  Expanded(child: Center(child: Text('RPE', style: TextStyle(fontWeight: FontWeight.bold)))),
                                  SizedBox(width: 40, child: Icon(Icons.check, size: 18, color: Colors.grey)),
                                ],
                              ),
                              const Divider(color: Colors.white24),

                              ...List.generate(sets.length, (setIndex) {
                                final setData = sets[setIndex];
                                final isDone = setData['isCompleted'] as bool;

                                return Dismissible(
                                  key: ObjectKey(setData),
                                  direction: DismissDirection.endToStart, 
                                  background: Container(
                                    color: Colors.redAccent.withValues(alpha: 0.8),
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: const Icon(Icons.delete, color: Colors.white),
                                  ),
                                  onDismissed: (direction) {
                                    sets.removeAt(setIndex);
                                    _manager.updateUI();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Row(
                                      children: [
                                        SizedBox(width: 30, child: Text('${setIndex + 1}', style: const TextStyle(fontSize: 16))),

                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                            child: TextFormField(
                                              key: ValueKey('weight_${index}_${setIndex}_$isDone'),
                                              initialValue: setData['weight']?.toString() ?? '', 
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                              textAlign: TextAlign.center,
                                              decoration: InputDecoration(
                                                hintText: setData['prevWeight']?.toString() ?? '-',
                                                hintStyle: const TextStyle(color: Colors.white38),
                                                filled: true,
                                                fillColor: isDone ? Colors.green.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.3),
                                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                              ),
                                              onChanged: (val) => setData['weight'] = val,
                                            ),
                                          ),
                                        ),

                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                            child: TextFormField(
                                              key: ValueKey('reps_${index}_${setIndex}_$isDone'),
                                              initialValue: setData['reps']?.toString() ?? '', 
                                              keyboardType: TextInputType.number,
                                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                              textAlign: TextAlign.center,
                                              decoration: InputDecoration(
                                                hintText: setData['prevReps']?.toString() ?? '-',
                                                hintStyle: const TextStyle(color: Colors.white38),
                                                filled: true,
                                                fillColor: isDone ? Colors.green.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.3),
                                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                              ),
                                              onChanged: (val) => setData['reps'] = val,
                                            ),
                                          ),
                                        ),

                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                            child: TextFormField(
                                              key: ValueKey('rpe_${index}_${setIndex}_$isDone'),
                                              initialValue: setData['rpe']?.toString() ?? '', 
                                              keyboardType: TextInputType.number,
                                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                              textAlign: TextAlign.center,
                                              decoration: InputDecoration(
                                                hintText: setData['prevRpe']?.toString() ?? '-',
                                                hintStyle: const TextStyle(color: Colors.white38),
                                                filled: true,
                                                fillColor: isDone ? Colors.green.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.3),
                                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                              ),
                                              onChanged: (val) => setData['rpe'] = val,
                                            ),
                                          ),
                                        ),

                                        SizedBox(
                                          width: 40,
                                          child: Checkbox(
                                            value: isDone,
                                            activeColor: Colors.green,
                                            onChanged: (val) {
                                              if (val == true && !_manager.isEditing) {
                                                if (setData['weight'] == '' && setData['prevWeight'] != '-') setData['weight'] = setData['prevWeight'];
                                                if (setData['reps'] == '' && setData['prevReps'] != '-') setData['reps'] = setData['prevReps'];
                                                if (setData['rpe'] == '' && setData['prevRpe'] != '-') setData['rpe'] = setData['prevRpe'];
                                                
                                                _manager.startRestTimer();
                                              }
                                              
                                              setData['isCompleted'] = val;
                                              _manager.updateUI();
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              TextButton.icon(
                                onPressed: () => _manager.addSetToExercise(index), 
                                icon: const Icon(Icons.add, size: 16), 
                                label: const Text('Add Set')
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          )
        );
      }
    );
  }
}