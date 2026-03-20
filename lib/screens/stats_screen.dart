import 'package:flutter/material.dart';
import 'package:mingym/models/gym_models.dart';
import 'package:mingym/services/firestore_service.dart';
import 'package:mingym/managers/active_workout_manager.dart';
import 'package:mingym/widgets/metric_expanded_overlay.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final FirestoreService _firestore = FirestoreService();

  void _openExpandedMetric(BuildContext context, String metricType, String value, IconData icon, Color color, List<WorkoutLog> history, {List<String>? exerciseList, List<BodyWeightLog>? weightHistory}) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false, 
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
              child: MetricExpandedOverlay(
                metricType: metricType,
                icon: icon,
                color: color,
                history: history,
                exerciseList: exerciseList,
                weightHistory: weightHistory ?? [],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: ActiveWorkoutManager(),
          builder: (context, child) {
            final manager = ActiveWorkoutManager();

            return StreamBuilder<List<WorkoutLog>>(
              stream: _firestore.getWorkoutHistoryStream(),
              builder: (context, workoutSnapshot) {
                return StreamBuilder<List<BodyWeightLog>>(
                  stream: _firestore.getBodyWeightHistoryStream(),
                  builder: (context, weightSnapshot) {
                    
                    if (workoutSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
                    }

                    final history = workoutSnapshot.data ?? [];
                    final weightHistory = weightSnapshot.data ?? [];
                    final totalWorkouts = history.length;
                    
                    final rawTotalVolume = history.fold<double>(0, (sum, log) => sum + log.totalVolume);
                    final displayVolume = manager.getDisplayWeight(rawTotalVolume);
                    
                    final totalMinutes = history.fold<int>(0, (sum, log) => sum + log.durationMinutes);

                    Set<String> uniqueExercises = {};
                    for (var log in history) {
                      for (var ex in log.exercises) {
                        if (ex.loggedSets.isNotEmpty) {
                          uniqueExercises.add(ex.name);
                        }
                      }
                    }
                    final exerciseList = uniqueExercises.toList()..sort();

                    double currentWeight = 0.0;
                    if (weightHistory.isNotEmpty) {
                      currentWeight = manager.getDisplayWeight(weightHistory.first.weight); 
                    }
                    
                    String weightStr = currentWeight > 0 ? '${currentWeight.toStringAsFixed(1)} ${manager.unitString}' : 'No Data';

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 35, 16, 0),
                      children: [
                        const Text('Statistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),

                        Row(
                      children: [
                        Expanded(child: _buildStandardMetricCard(context, 'Workouts', 'Workouts', totalWorkouts.toString(), Icons.fitness_center, Colors.blueAccent, history)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStandardMetricCard(context, 'Volume', 'Volume (${manager.unitString})', '${(displayVolume / 1000).toStringAsFixed(1)}k', Icons.bar_chart, Colors.green, history)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStandardMetricCard(context, 'Time', 'Time', '${(totalMinutes / 60).toStringAsFixed(1)}h', Icons.timer, Colors.orangeAccent, history)),
                      ],
                    ),
                        
                        const SizedBox(height: 12), 

                        Row(
                          children: [
                            Expanded(
                              child: _buildActionCard(
                                context, 
                                'View 1RM\nEstimates', 
                                Icons.trending_up, 
                                Colors.redAccent, 
                                () => _openExpandedMetric(context, '1RM Estimates', 'View', Icons.trending_up, Colors.redAccent, history, exerciseList: exerciseList)
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStandardMetricCard(
                                context,
                                'Weight',
                                'Weight', 
                                weightStr,
                                Icons.monitor_weight_outlined, 
                                Colors.purpleAccent, 
                                history,
                                weightHistory: weightHistory, 
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }
                );
              }
            );
          }
        ),
      ),
    );
  }

  Widget _buildStandardMetricCard(BuildContext context, String metricType, String title, String value, IconData icon, Color color, List<WorkoutLog> history, {List<BodyWeightLog>? weightHistory}) {
    return GestureDetector(
      onTap: () => _openExpandedMetric(context, metricType, value, icon, color, history, weightHistory: weightHistory),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String text, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }
}
