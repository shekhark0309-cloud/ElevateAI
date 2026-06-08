import 'package:flutter/material.dart';

class DNACard extends StatelessWidget {
  final String archetype;
  final List<String> skills;
  final double confidence;

  const DNACard({
    super.key,
    required this.archetype,
    required this.skills,
    required this.confidence,
  });

  IconData _getArchetypeIcon() {
    switch (archetype.toLowerCase()) {
      case 'builder': return Icons.build_circle_outlined;
      case 'strategist': return Icons.insights_outlined;
      case 'creative': return Icons.palette_outlined;
      case 'executor': return Icons.task_alt_outlined;
      default: return Icons.person_outline;
    }
  }

  Color _getArchetypeColor() {
    switch (archetype.toLowerCase()) {
      case 'builder': return Colors.blue;
      case 'strategist': return Colors.purple;
      case 'creative': return Colors.pink;
      case 'executor': return Colors.green;
      default: return Colors.indigo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getArchetypeColor();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.1), Colors.white],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getArchetypeIcon(), size: 40, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        archetype,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        'Archetype Confidence: ${(confidence * 100).toInt()}%',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text(
              'TOP SKILLS',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: skills.map((skill) => Chip(
                label: Text(skill, style: const TextStyle(fontSize: 12)),
                backgroundColor: color.withValues(alpha: 0.05),
                side: BorderSide(color: color.withValues(alpha: 0.2)),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
