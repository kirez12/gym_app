import 'package:flutter/material.dart';
import 'package:mingym/models/gym_models.dart';
import 'package:mingym/services/firestore_service.dart';

class AddRoutineSheet extends StatefulWidget {
  final Routine? editRoutine;

  const AddRoutineSheet({super.key, this.editRoutine});

  @override
  State<AddRoutineSheet> createState() => _AddRoutineSheetState();
}

class _ExerciseInput {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController setsController = TextEditingController();
}

class _AddRoutineSheetState extends State<AddRoutineSheet> {
  final _firestore = FirestoreService();
  late TextEditingController _titleController;
  final List<_ExerciseInput> _exercises = [];

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.editRoutine?.title ?? '');

    if (widget.editRoutine != null && widget.editRoutine!.exercises.isNotEmpty) {
      for (var ex in widget.editRoutine!.exercises) {
        final input = _ExerciseInput();
        input.nameController.text = ex.name;
        input.setsController.text = ex.sets.toString();
        _exercises.add(input);
      }
    } else {
      _exercises.add(_ExerciseInput());
    }
  }

  void _addExerciseRow() {
    setState(() {
      _exercises.add(_ExerciseInput());
    });
  }

  void _removeExerciseRow(int index) {
    setState(() {
      _exercises.removeAt(index);
    });
  }

  Future<void> _saveRoutine() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final List<Exercise> exerciseModels = _exercises.map((input) {
      return Exercise(
        name: input.nameController.text.trim(),
        sets: int.tryParse(input.setsController.text) ?? 0,
      );
    }).where((e) => e.name.isNotEmpty && e.sets > 0).toList();

    if (exerciseModels.isEmpty) return;

    final newRoutine = Routine(
      id: widget.editRoutine?.id ?? '', 
      title: title,
      exercises: exerciseModels,
    );

    await _firestore.saveRoutine(newRoutine);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var e in _exercises) {
      e.nameController.dispose();
      e.setsController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomInset,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.editRoutine != null ? 'Edit Routine' : 'Create New Routine', 
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Routine Name (e.g. Upper Body Power)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),

          const Text('Exercises', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _exercises.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _exercises[index].nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(hintText: 'Exercise Name', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _exercises[index].setsController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(hintText: 'Sets', isDense: true),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                      onPressed: () => _removeExerciseRow(index),
                    ),
                  ],
                ),
              );
            },
          ),
          
          TextButton.icon(
            onPressed: _addExerciseRow,
            icon: const Icon(Icons.add),
            label: const Text('Add Exercise'),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _saveRoutine,
              child: Text(
                widget.editRoutine != null ? 'Update Routine' : 'Save Routine', 
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}