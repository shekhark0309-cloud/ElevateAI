import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/chat_service.dart';

class TeamMatchCard extends StatelessWidget {
  final Map<String, dynamic> match;
  final VoidCallback? onAdd;

  const TeamMatchCard({super.key, required this.match, this.onAdd});

  Widget _buildReliabilityBadge(Map<String, dynamic> insight) {
    final color = _getColor(insight['color']);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(insight['is_warning'] ? Icons.warning_amber_rounded : Icons.verified_user, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            insight['status'].toString().toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Color _getColor(String colorName) {
    switch (colorName) {
      case 'red': return Colors.red;
      case 'green': return Colors.green;
      case 'blue': return Colors.blue;
      case 'orange': return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fit = (match['composite_score'] as num?)?.toInt() ?? 0;
    final health = (match['team_health_score'] as num?)?.toInt() ?? 70;
    final leaderTier = match['leader_trust_tier'] ?? 'Unverified';
    final relInsight = match['reliability_insight'];
    final missingRoles = match['missing_roles'] as List? ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (relInsight != null) ...[
              _buildReliabilityBadge(relInsight),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.indigo[100],
                  child: const Icon(Icons.group, color: Colors.indigo),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match['name'] ?? 'Team Name',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Leader: ${match['leader_name']} • $leaderTier',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Text(
                        '$fit% FIT',
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Health: $health%', style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              match['match_explanation'] ?? 'No explanation provided.',
              style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            const Text(
              'NEEDS:',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: ((match['required_skills'] as List?) ?? []).take(3).map((s) => Chip(
                label: Text(s.toString(), style: const TextStyle(fontSize: 10)),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              )).toList(),
            ),
            if (missingRoles.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'AI SUGGESTED MISSING ROLES:',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.indigo, letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: missingRoles.map((r) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigo[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.indigo[100]!),
                  ),
                  child: Text(r.toString(), style: const TextStyle(fontSize: 9, color: Colors.indigo, fontWeight: FontWeight.bold)),
                )).toList(),
              ),
            ],
            if (onAdd != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Add this person'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () async {
                      final chatService = ChatService();
                      final leaderId = match['leader_id']; // Ensure leader_id is in match data
                      if (leaderId != null) {
                        final convId = await chatService.getOrCreateConversation(leaderId);
                        if (context.mounted) {
                          context.push('/chat/$convId?name=${match['leader_name']}');
                        }
                      }
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
