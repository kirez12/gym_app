import 'package:flutter/material.dart';
import 'package:mingym/services/firestore_service.dart'; 

class ExerciseSelectionScreen extends StatefulWidget {
  const ExerciseSelectionScreen({super.key});

  @override
  State<ExerciseSelectionScreen> createState() => _ExerciseSelectionScreenState();
}

class _ExerciseSelectionScreenState extends State<ExerciseSelectionScreen> {
  String _searchQuery = '';
  String _selectedMuscle = 'All';

  List<Map<String, dynamic>> _defaultExercises = [];
  bool _isLoadingDefaults = true;

  final List<String> _muscleGroups = ['All', 'Chest', 'Back', 'Legs', 'Shoulders', 'Arms', 'Core'];
  final List<String> _equipmentTypes = [
    'Barbell', 'Dumbbell', 'Machine', 'Cable', 'Smith Machine', 
    'EZ Bar', 'Bodyweight', 'Band', 'Kettlebell', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadDefaultExercises();
  }

  Future<void> _loadDefaultExercises() async {
    final exercises = await FirestoreService().getDefaultExercises();
    setState(() {
      _defaultExercises = exercises;
      _isLoadingDefaults = false;
    });
  }

  String _generateFullName(String parent, String equipment, bool isSingleArm) {
    String prefix = isSingleArm ? "Single Arm " : "";
    return "$prefix$parent ($equipment)";
  }

  void _showAddExerciseDialog() {
    String newParentName = '';
    String newMuscle = 'Chest';
    String newEquipment = 'Barbell';
    bool newIsSingleArm = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey.shade900,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Create Exercise', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (val) => newParentName = val,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Exercise Name (e.g. Bench Press)',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.3),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      initialValue: newMuscle,
                      dropdownColor: Colors.grey.shade800,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Muscle Group',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.3),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: _muscleGroups.where((m) => m != 'All').map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (val) => setDialogState(() => newMuscle = val!),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: newEquipment,
                      dropdownColor: Colors.grey.shade800,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Equipment',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.3),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: _equipmentTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setDialogState(() => newEquipment = val!),
                    ),
                    const SizedBox(height: 12),

                    CheckboxListTile(
                      title: const Text('Single Arm', style: TextStyle(color: Colors.white)),
                      value: newIsSingleArm,
                      activeColor: Colors.blueAccent,
                      checkColor: Colors.white,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setDialogState(() => newIsSingleArm = val!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey))
                ),
                ElevatedButton(
                  onPressed: () {
                    if (newParentName.trim().isEmpty) return;
                    
                    final fullName = _generateFullName(newParentName.trim(), newEquipment, newIsSingleArm);
                    
                    FirestoreService().saveCustomExercise({
                      'parent': newParentName.trim(),
                      'equipment': newIsSingleArm ? 'Single Arm $newEquipment' : newEquipment,
                      'fullName': fullName,
                      'muscle': newMuscle,
                    });
                    
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingDefaults) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)));
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService().getCustomExercisesStream(),
      builder: (context, snapshot) {
        
        final customExercises = snapshot.data ?? [];
        final allExercises = [..._defaultExercises, ...customExercises];

        final filteredExercises = allExercises.where((ex) {
          final matchesSearch = ex['fullName'].toLowerCase().contains(_searchQuery.toLowerCase()) || 
                                ex['parent'].toLowerCase().contains(_searchQuery.toLowerCase());
          final matchesMuscle = _selectedMuscle == 'All' || ex['muscle'] == _selectedMuscle;
          return matchesSearch && matchesMuscle;
        }).toList();

        Map<String, List<Map<String, dynamic>>> groupedExercises = {};
        for (var ex in filteredExercises) {
          final parent = ex['parent'] as String;
          if (!groupedExercises.containsKey(parent)) {
            groupedExercises[parent] = [];
          }
          groupedExercises[parent]!.add(ex);
        }

        final sortedParentKeys = groupedExercises.keys.toList()..sort();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Select Exercise'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: Colors.blueAccent, size: 28),
                onPressed: _showAddExerciseDialog,
                tooltip: 'Create Custom Exercise',
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(120),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search exercises...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey.shade900,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      itemCount: _muscleGroups.length,
                      itemBuilder: (context, index) {
                        final muscle = _muscleGroups[index];
                        final isSelected = _selectedMuscle == muscle;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: Text(muscle),
                            selected: isSelected,
                            selectedColor: Colors.blueAccent.withValues(alpha: 0.3),
                            backgroundColor: Colors.grey.shade900,
                            showCheckmark: false,
                            labelStyle: TextStyle(color: isSelected ? Colors.blueAccent : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedMuscle = muscle);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: ListView.separated(
            itemCount: sortedParentKeys.length,
            separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 1),
            itemBuilder: (context, index) {
              final parent = sortedParentKeys[index];
              final children = groupedExercises[parent]!;
              final muscle = children.first['muscle'];

              if (children.length == 1) {
                final exercise = children.first;
                return ListTile(
                  title: Text(exercise['fullName'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Text(muscle, style: const TextStyle(color: Colors.grey)),
                  trailing: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                  onTap: () => Navigator.pop(context, exercise['fullName']),
                );
              }

              return Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent), 
                child: ExpansionTile(
                  title: Text(parent, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Text(muscle, style: const TextStyle(color: Colors.grey)),
                  iconColor: Colors.blueAccent,
                  collapsedIconColor: Colors.grey,
                  children: children.map((exercise) {
                    return Container(
                      color: Colors.black.withValues(alpha: 0.2), 
                      child: ListTile(
                        contentPadding: const EdgeInsets.only(left: 32.0, right: 16.0), 
                        title: Text(exercise['equipment'], style: const TextStyle(color: Colors.white70)),
                        trailing: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                        onTap: () => Navigator.pop(context, exercise['fullName']),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        );
      }
    );
  }
}