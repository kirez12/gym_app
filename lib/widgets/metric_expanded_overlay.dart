import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mingym/models/gym_models.dart';
import 'package:mingym/services/firestore_service.dart';
import 'package:mingym/managers/active_workout_manager.dart';

class MetricExpandedOverlay extends StatefulWidget {
  final String metricType; 
  final IconData icon;
  final Color color;
  final List<WorkoutLog> history;
  final List<String>? exerciseList;
  final List<BodyWeightLog> weightHistory; 

  const MetricExpandedOverlay({
    super.key, 
    required this.metricType, 
    required this.icon, 
    required this.color,
    required this.history,
    this.exerciseList,
    required this.weightHistory,
  });

  @override
  State<MetricExpandedOverlay> createState() => _MetricExpandedOverlayState();
}

class _MetricExpandedOverlayState extends State<MetricExpandedOverlay> {
  String _timeframe = 'Week'; 
  int _timeOffset = 0;
  String? _selectedExercise;

  @override
  void initState() {
    super.initState();
    if (widget.exerciseList != null && widget.exerciseList!.isNotEmpty) {
      _selectedExercise = widget.exerciseList!.first;
    }
  }

  void _changeTimeframe(String newTimeframe) {
    setState(() {
      _timeframe = newTimeframe;
      _timeOffset = 0; 
    });
  }

  void _showAddWeightDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Bodyweight', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. 80.5',
            hintStyle: const TextStyle(color: Colors.grey),
            suffixText: 'kg',
            suffixStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.3),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                FirestoreService().logBodyWeight(val);
                setState(() {});
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: widget.color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    
    if (_timeframe == 'Week') {
      final offsetDate = now.add(Duration(days: _timeOffset * 7));
      final monday = offsetDate.subtract(Duration(days: offsetDate.weekday - 1));
      final start = DateTime(monday.year, monday.month, monday.day);
      return DateTimeRange(start: start, end: start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59)));
      
    } else if (_timeframe == 'Month') {
      final start = DateTime(now.year, now.month + _timeOffset, 1);
      final end = DateTime(start.year, start.month + 1, 0, 23, 59, 59); 
      return DateTimeRange(start: start, end: end);
      
    } else {
      final start = DateTime(now.year + _timeOffset, 1, 1);
      final end = DateTime(start.year, 12, 31, 23, 59, 59);
      return DateTimeRange(start: start, end: end);
    }
  }

  String _getPeriodTitle(DateTimeRange range) {
    if (_timeframe == 'Week') {
      if (_timeOffset == 0) return 'This Week';
      if (_timeOffset == -1) return 'Last Week';
      return '${range.start.day}/${range.start.month} - ${range.end.day}/${range.end.month}';
    } else if (_timeframe == 'Month') {
      if (_timeOffset == 0) return 'This Month';
      if (_timeOffset == -1) return 'Last Month';
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[range.start.month - 1]} ${range.start.year}';
    } else {
      if (_timeOffset == 0) return 'This Year';
      if (_timeOffset == -1) return 'Last Year';
      return '${range.start.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = _getDateRange();
    final manager = ActiveWorkoutManager();
    final filteredData = widget.history.where((log) =>
      log.date.isAfter(range.start.subtract(const Duration(seconds: 1))) && log.date.isBefore(range.end)
    ).toList();
    
    int numBuckets = _timeframe == 'Week' ? 7 : (_timeframe == 'Month' ? range.end.day : 12);
    List<double> bucketValues = List.filled(numBuckets, 0.0);
    
    if (widget.metricType == '1RM Estimates' && _selectedExercise != null) {
      for (var log in filteredData) {
        for (var ex in log.exercises) {
          if (ex.name == _selectedExercise) {
            double maxInSession = 0;
            for (var set in ex.loggedSets) {
              if (set.reps <= 0) continue;
              double est = set.reps == 1 ? set.weight : set.weight * (1 + (set.reps / 30.0));
              if (est > maxInSession) maxInSession = est;
            }
            if (maxInSession > 0) {
              int bIndex = _timeframe == 'Week' ? log.date.weekday - 1 : (_timeframe == 'Month' ? log.date.day - 1 : log.date.month - 1);
              double displayEst = manager.getDisplayWeight(maxInSession);
              if (displayEst > bucketValues[bIndex]) bucketValues[bIndex] = displayEst;
            }
          }
        }
      }
    } else if (widget.metricType == 'Weight') {
      double lastKnownWeight = 0;
      final pastWeights = widget.weightHistory.where((log) => log.date.isBefore(range.start)).toList();
      if (pastWeights.isNotEmpty) {
        pastWeights.sort((a, b) => b.date.compareTo(a.date)); 
        lastKnownWeight = pastWeights.first.weight;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (int i = 0; i < numBuckets; i++) {
        DateTime bucketDate = _timeframe == 'Week' ? range.start.add(Duration(days: i)) : (_timeframe == 'Month' ? DateTime(range.start.year, range.start.month, i + 1) : DateTime(range.start.year, i + 1, 1));
        
        List<BodyWeightLog> bucketLogs = [];
        for (var log in widget.weightHistory) {
           if (log.date.isBefore(range.start) || log.date.isAfter(range.end)) continue;
           int bIndex = _timeframe == 'Week' ? log.date.weekday - 1 : (_timeframe == 'Month' ? log.date.day - 1 : log.date.month - 1);
           if (bIndex == i) bucketLogs.add(log);
        }
        
        if (bucketLogs.isNotEmpty) {
          bucketLogs.sort((a, b) => b.date.compareTo(a.date)); 
          lastKnownWeight = bucketLogs.first.weight;
        }
        
        bucketValues[i] = bucketDate.isAfter(today) ? 0 : manager.getDisplayWeight(lastKnownWeight); 
      }
    } else {
      for (var log in filteredData) {
        double value = 0;
        if (widget.metricType == 'Workouts') value = 1; 
        if (widget.metricType == 'Volume') value = manager.getDisplayWeight(log.totalVolume);
        if (widget.metricType == 'Time') value = log.durationMinutes.toDouble();

        int bIndex = _timeframe == 'Week' ? log.date.weekday - 1 : (_timeframe == 'Month' ? log.date.day - 1 : log.date.month - 1);
        bucketValues[bIndex] += value;
      }
    }

    List<BarChartGroupData> barGroups = [];
    double maxVal = 0;
    double minVal = 9999;
    
    for (int i = 0; i < numBuckets; i++) {
      if (bucketValues[i] > maxVal) maxVal = bucketValues[i];
      if (bucketValues[i] < minVal && bucketValues[i] > 0) minVal = bucketValues[i];
      
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: bucketValues[i],
              color: widget.color,
              width: _timeframe == 'Month' ? 6 : 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    double maxY = maxVal > 0 ? maxVal * 1.2 : 1; 
    double minY = 0; 
    double yInterval = 1;
    
    if (widget.metricType == 'Weight') {
      if (minVal != 9999 && maxVal > 0) {
        minY = (minVal - 5).floorToDouble(); 
        if (minY < 0) minY = 0;
        maxY = (maxVal + 5).ceilToDouble();
      } else {
        maxY = 100;
      }
      yInterval = 5; 
    } else if (widget.metricType == 'Volume' || widget.metricType == '1RM Estimates') {
      yInterval = ((maxY / 4) / 10).ceilToDouble() * 10; 
      if (yInterval < 10) yInterval = 10;
      maxY = (maxY / yInterval).ceilToDouble() * yInterval;
    } else if (widget.metricType == 'Time') {
      yInterval = (maxY / 4).ceilToDouble();
      if (yInterval < 5) yInterval = 5; 
      maxY = (maxY / yInterval).ceilToDouble() * yInterval;
    } else {
      yInterval = (maxY / 3).ceilToDouble();
      if (yInterval < 1) yInterval = 1; 
      maxY = (maxY / yInterval).ceilToDouble() * yInterval;
    }
    if (maxY == 0) maxY = yInterval;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.8), 
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              height: 560, 
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5)
                ]
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(widget.icon, color: widget.color, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.metricType, 
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            if (widget.metricType == 'Weight')
                              IconButton(
                                icon: Icon(Icons.add_circle, color: widget.color, size: 28),
                                onPressed: _showAddWeightDialog,
                              ),
                            IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                          ],
                        )
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),

                  if (widget.metricType == '1RM Estimates' && widget.exerciseList != null && widget.exerciseList!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedExercise,
                            dropdownColor: Colors.grey.shade900,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.redAccent),
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            items: widget.exerciseList!.map((ex) => DropdownMenuItem(value: ex, child: Text(ex))).toList(),
                            onChanged: (val) => setState(() => _selectedExercise = val),
                          ),
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: ['Week', 'Month', 'Year'].map((tf) {
                          final isSelected = _timeframe == tf;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => _changeTimeframe(tf),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? widget.color.withValues(alpha: 0.2) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    tf,
                                    style: TextStyle(
                                      color: isSelected ? widget.color : Colors.grey,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Colors.white),
                          onPressed: () => setState(() => _timeOffset--),
                        ),
                        Text(
                          _getPeriodTitle(range),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right, color: _timeOffset < 0 ? Colors.white : Colors.grey.shade800),
                          onPressed: _timeOffset < 0 ? () => setState(() => _timeOffset++) : null, 
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: GestureDetector(
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity != null) {
                          if (details.primaryVelocity! < -300 && _timeOffset < 0) {
                            setState(() => _timeOffset++); 
                          } else if (details.primaryVelocity! > 300) {
                            setState(() => _timeOffset--); 
                          }
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 24.0, left: 8.0, bottom: 24.0, top: 16.0),
                        child: BarChart(
                          key: ValueKey(_timeframe), 
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: maxY,
                            minY: minY,
                            barGroups: barGroups,
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: true, 
                              drawHorizontalLine: true,
                              horizontalInterval: yInterval,
                              verticalInterval: 1, 
                              getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1),
                              getDrawingVerticalLine: (value) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1),
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border(
                                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
                                left: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
                              ),
                            ),
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  DateTime spotDate = _timeframe == 'Week' ? range.start.add(Duration(days: group.x)) : (_timeframe == 'Month' ? DateTime(range.start.year, range.start.month, group.x + 1) : DateTime(range.start.year, group.x + 1, 1));
                                  String dateStr = _timeframe == 'Year' ? '${spotDate.month}/${spotDate.year}' : '${spotDate.day}/${spotDate.month}';
                                  
                                  String valStr = rod.toY.toStringAsFixed(0);
                                  if (widget.metricType == 'Volume') valStr = '${(rod.toY / 1000).toStringAsFixed(1)}k kg';
                                  if (widget.metricType == 'Time') valStr = '$valStr min';
                                  if (widget.metricType == '1RM Estimates' || widget.metricType == 'Weight') valStr = '${rod.toY.toStringAsFixed(1)} kg';
                                  
                                  return BarTooltipItem('$dateStr\n$valStr', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 28,
                                  interval: 1, 
                                  getTitlesWidget: (value, meta) {
                                    int index = value.toInt();
                                    if (index < 0 || index >= numBuckets) return const SizedBox();
                                    String label = '';
                                    if (_timeframe == 'Week') {
                                      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                                      label = days[index];
                                    } else if (_timeframe == 'Month') {
                                      int day = index + 1;
                                      if (day == 1 || day == 8 || day == 15 || day == 22 || day == 29) {
                                        label = '$day/${range.start.month}'; 
                                      }
                                    } else {
                                      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                                      label = months[index];
                                    }
                                    return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)));
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 36,
                                  interval: yInterval,
                                  getTitlesWidget: (value, meta) {
                                    if (value == 0) return const Text('0', style: TextStyle(color: Colors.grey, fontSize: 10)); 
                                    String label = value.toStringAsFixed(0);
                                    if (widget.metricType == 'Volume' || widget.metricType == '1RM Estimates' || widget.metricType == 'Weight') {
                                      label = value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : label;
                                    }
                                    return Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10));
                                  },
                                ),
                              ),
                            ),
                          ),
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}