import 'package:flutter/material.dart';
import '../models/team_analysis_model.dart';

class TeamAnalysisView extends StatelessWidget {
  final TeamAnalysis analysis;

  const TeamAnalysisView({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Team Analysis',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getHealthColor(analysis.healthScore).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${analysis.healthScore}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _getHealthColor(analysis.healthScore),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Health Score',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 24),
            _buildStrengthsGrid(),
            const SizedBox(height: 24),
            const Text(
              'AI SUMMARY',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            Text(
              analysis.teamStrengthSummary,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'MISSING ROLES',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: analysis.missingRoles.map((role) => _buildMissingRoleChip(role)).toList(),
            ),
            const SizedBox(height: 24),
            if (analysis.riskIndicators.isNotEmpty) ...[
              const Text(
                'RISK INDICATORS',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
              ),
              const SizedBox(height: 12),
              ...analysis.riskIndicators.map((risk) => _buildRiskItem(risk)).toList(),
              const SizedBox(height: 24),
            ],
            if (analysis.suggestedMembers.isNotEmpty) ...[
              const Text(
                'SUGGESTED MEMBERS',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
              ),
              const SizedBox(height: 12),
              ...analysis.suggestedMembers.map((member) => _buildSuggestedMember(member)).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStrengthsGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2,
      children: analysis.strengths.entries.map((e) => _buildStrengthCard(e.key, e.value)).toList(),
    );
  }

  Widget _buildStrengthCard(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 4),
          Text('$value%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMissingRoleChip(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_circle_outline, size: 14, color: Colors.indigo),
          const SizedBox(width: 6),
          Text(
            role,
            style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskItem(String risk) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(child: Text(risk, style: const TextStyle(fontSize: 13, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildSuggestedMember(Map<String, dynamic> member) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Colors.indigo.shade100,
        child: Text(member['full_name']?[0] ?? 'S'),
      ),
      title: Text(member['full_name'] ?? 'Student', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text('${member['archetype']} • ${member['trust_tier']}', style: const TextStyle(fontSize: 12)),
      trailing: TextButton(onPressed: () {}, child: const Text('Invite')),
    );
  }

  Color _getHealthColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
}
