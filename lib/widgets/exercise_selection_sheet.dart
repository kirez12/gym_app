import 'package:flutter/material.dart';

class ExerciseSelectionSheet extends StatefulWidget {
  const ExerciseSelectionSheet({super.key});

  @override
  State<ExerciseSelectionSheet> createState() => _ExerciseSelectionSheetState();
}

class _ExerciseSelectionSheetState extends State<ExerciseSelectionSheet> {
  String _searchQuery = '';
  final List<Map<String, String>> _masterExerciseList = [
    {'name': 'Barbell Bench Press', 'category': 'Chest'},
    {'name': 'Incline Dumbbell Press', 'category': 'Chest'},
    {'name': 'Cable Crossover', 'category': 'Chest'},
    {'name': 'Back Squat', 'category': 'Legs'},
    {'name': 'Leg Press', 'category': 'Legs'},
    {'name': 'Romanian Deadlift', 'category': 'Legs'},
    {'name': 'Overhead Press', 'category': 'Shoulders'},
    {'name': 'Lateral Raise', 'category': 'Shoulders'},
    {'name': 'Pull-Up', 'category': 'Back'},
    {'name': 'Barbell Row', 'category': 'Back'},
    {'name': 'Lat Pulldown', 'category': 'Back'},
    {'name': 'Barbell Curl', 'category': 'Arms'},
    {'name': 'Tricep Pushdown', 'category': 'Arms'},
  ];

  @override
  Widget build(BuildContext context) {
    final filteredExercises = _masterExerciseList.where((exercise) {
      return exercise['name']!.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Select Exercise', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search exercises...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            const Divider(color: Colors.white12),

            Expanded(
              child: ListView.builder(
                itemCount: filteredExercises.length,
                itemBuilder: (context, index) {
                  final exercise = filteredExercises[index];
                  return ListTile(
                    title: Text(exercise['name']!, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(exercise['category']!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    trailing: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                    onTap: () {
                      Navigator.pop(context, exercise['name']);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}