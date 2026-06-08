import 'package:flutter/material.dart';

class OpportunityCard extends StatelessWidget {
  final Map<String, dynamic> opportunity;

  const OpportunityCard({super.key, required this.opportunity});

  Color _getUrgencyColor() {
    final urgency = opportunity['urgency_level']?.toString().toLowerCase();
    switch (urgency) {
      case 'critical': return Colors.red;
      case 'high': return Colors.orange;
      case 'medium': return Colors.blue;
      default: return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getUrgencyColor();
    final type = opportunity['type']?.toString().toUpperCase() ?? 'OPPORTUNITY';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {}, // Navigate to detail
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (opportunity['is_featured'] == true)
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                opportunity['title'] ?? 'Untitled Opportunity',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                opportunity['organizer_name'] ?? 'Organizer',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Ends in ${opportunity['days_until_deadline'] ?? '?'} days',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Spacer(),
                  if (opportunity['match_score'] != null)
                    Text(
                      '${(opportunity['match_score'] as num).toInt()}% Match',
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
