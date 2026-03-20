import 'package:flutter/material.dart';

class WorkoutEditorScreen extends StatefulWidget {
  final List<Map<String, dynamic>> exercises;

  const WorkoutEditorScreen({super.key, required this.exercises});

  @override
  State<WorkoutEditorScreen> createState() => _WorkoutEditorScreenState();
}

class _WorkoutEditorScreenState extends State<WorkoutEditorScreen> {
  late List<Map<String, dynamic>> _reorderedExercises;

  @override
  void initState() {
    super.initState();
    _reorderedExercises = List.from(widget.exercises);
  }

  void _removeExercise(int index) {
    setState(() {
      _reorderedExercises.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Exercises'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, _reorderedExercises);
            },
            child: const Text('Save', style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Theme(
        data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
        child: ReorderableListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _reorderedExercises.length,
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
              final item = _reorderedExercises.removeAt(oldIndex);
              _reorderedExercises.insert(newIndex, item);
            });
          },
          itemBuilder: (context, index) {
            final exercise = _reorderedExercises[index];
            
            return Card(
              key: ObjectKey(exercise),
              color: Colors.grey.shade900,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        exercise['name'], 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _removeExercise(index),
                    ),
                    const Icon(Icons.drag_handle, color: Colors.grey),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}