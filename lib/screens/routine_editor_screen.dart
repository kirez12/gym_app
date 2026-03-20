import 'package:flutter/material.dart';
import 'package:mingym/models/gym_models.dart';
import 'package:mingym/services/firestore_service.dart';
import 'package:mingym/screens/exercise_selection_screen.dart';
import 'package:uuid/uuid.dart';

class RoutineEditorScreen extends StatefulWidget {
  final Routine? editRoutine;

  const RoutineEditorScreen({super.key, this.editRoutine});

  @override
  State<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _ExerciseInput {
  final String key;
  String name = '';
  final TextEditingController setsController = TextEditingController();

  _ExerciseInput({required this.key});
}

class _RoutineEditorScreenState extends State<RoutineEditorScreen> {
  final _firestore = FirestoreService();
  final _uuid = const Uuid();
  late TextEditingController _titleController;
  final List<_ExerciseInput> _exercises = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.editRoutine?.title ?? '');

    if (widget.editRoutine != null && widget.editRoutine!.exercises.isNotEmpty) {
      for (var ex in widget.editRoutine!.exercises) {
        final input = _ExerciseInput(key: _uuid.v4());
        input.name = ex.name;
        input.setsController.text = ex.sets.toString();
        _exercises.add(input);
      }
    }
  }

  void _removeExerciseRow(int index) {
    setState(() => _exercises.removeAt(index));
  }

  Future<void> _saveRoutine() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a routine title')));
      return;
    }

    final List<Exercise> exerciseModels = _exercises.map((input) {
      return Exercise(name: input.name, sets: int.tryParse(input.setsController.text) ?? 0);
    }).where((e) => e.name.isNotEmpty && e.sets > 0).toList();

    if (exerciseModels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one valid exercise')));
      return;
    }

    final newRoutine = Routine(
      id: widget.editRoutine?.id ?? '', 
      title: title,
      exercises: exerciseModels,
      sortIndex: widget.editRoutine?.sortIndex ?? -1, 
    );

    await _firestore.saveRoutine(newRoutine);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var e in _exercises) {e.setsController.dispose();}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editRoutine != null ? 'Edit Routine' : 'New Routine'),
        actions: [
          TextButton(
            onPressed: _saveRoutine,
            child: const Text('Save', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
               controller: _titleController,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Routine Name',
                border: InputBorder.none,
              ),
            ),
          ),
          const Divider(color: Colors.white12),
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
              child: ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _exercises.length,
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
                    final item = _exercises.removeAt(oldIndex);
                    _exercises.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  return Card(
                    key: ValueKey(_exercises[index].key),
                    color: Colors.grey.shade900,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(_exercises[index].name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          const Text('Sets: ', style: TextStyle(color: Colors.grey)),
                          SizedBox(
                            width: 50,
                            child: TextField(
                              controller: _exercises[index].setsController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                isDense: true,
                                filled: true,
                                fillColor: Colors.black.withValues(alpha: 0.3),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () => _removeExerciseRow(index),
                          ),
                          const Icon(Icons.drag_handle, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final selectedExerciseName = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(builder: (context) => const ExerciseSelectionScreen()),
                  );

                  if (selectedExerciseName != null) {
                    setState(() {
                      final input = _ExerciseInput(key: _uuid.v4());
                      input.name = selectedExerciseName;
                      input.setsController.text = '3'; 
                      _exercises.add(input);
                    });
                  }
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Add Exercise', style: TextStyle(fontSize: 16, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}