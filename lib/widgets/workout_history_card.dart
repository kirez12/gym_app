import 'package:flutter/material.dart';

class WorkoutHistoryCard extends StatefulWidget {
  final String title;
  final String dateText;
  final double displayVol;
  final String unitString;
  final int duration;
  final String exerciseText;
  final bool isLive;
  final VoidCallback? onResume;
  final Function(String)? onMenuSelected;

  const WorkoutHistoryCard({
    super.key,
    required this.title,
    required this.dateText,
    required this.displayVol,
    required this.unitString,
    required this.duration,
    required this.exerciseText,
    this.isLive = false,
    this.onResume,
    this.onMenuSelected,
  });

  @override
  State<WorkoutHistoryCard> createState() => _WorkoutHistoryCardState();
}

class _WorkoutHistoryCardState extends State<WorkoutHistoryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: widget.isLive ? Colors.blueAccent.withValues(alpha: 0.1) : Colors.grey.shade900,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: widget.isLive ? const BorderSide(color: Colors.blueAccent, width: 1) : BorderSide.none,
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: Radius.circular(_isExpanded ? 0 : 16),
            ),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Row(
                children: [
                  Icon(
                    widget.isLive ? Icons.play_circle_outline : Icons.check_circle,
                    color: widget.isLive ? Colors.orangeAccent : Colors.green,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(widget.dateText, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.fitness_center, size: 12, color: Colors.blueAccent),
                      const SizedBox(width: 2),
                      Text('${widget.displayVol.toStringAsFixed(0)}${widget.unitString}', 
                          style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Icon(Icons.timer_outlined, size: 12, color: Colors.orangeAccent),
                      const SizedBox(width: 2),
                      Text('${widget.duration}m', 
                          style: const TextStyle(fontSize: 12, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                    size: 20,
                  ),
                  if (widget.isLive)
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, color: Colors.blueAccent, size: 16),
                      onPressed: widget.onResume,
                    )
                  else
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                      color: Colors.grey.shade800,
                      surfaceTintColor: Colors.transparent,
                      onSelected: widget.onMenuSelected,
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Edit', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.redAccent, size: 18),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.exerciseText.isEmpty ? "No exercises recorded." : widget.exerciseText,
                  style: const TextStyle(color: Colors.white70, height: 1.5, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}