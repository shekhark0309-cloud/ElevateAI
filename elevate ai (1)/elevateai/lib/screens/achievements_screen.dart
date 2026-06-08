import 'package:flutter/material.dart';
import '../flutter_integration.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _achievements = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final data = await supabase
            .from('student_achievements')
            .select()
            .eq('student_id', user.id)
            .order('issued_at', ascending: false);

        if (mounted) {
          setState(() {
            _achievements = List<Map<String, dynamic>>.from(data);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Achievements', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _achievements.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _achievements.length,
              itemBuilder: (context, index) {
                final a = _achievements[index];
                return _achievementCard(
                  title: a['title'],
                  type: a['achievement_type'] ?? 'Award',
                  issuer: a['issued_by'] ?? 'Organization',
                  date: a['issued_at'] ?? 'N/A',
                  isVerified: a['is_verified'] == true,
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 24),
          const Text('No achievements yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Your verified certificates and awards will appear here.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _achievementCard({
    required String title,
    required String type,
    required String issuer,
    required String date,
    required bool isVerified,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('$type • $issuer', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Issued: $date', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
              ],
            ),
          ),
          if (isVerified)
            const Tooltip(
              message: 'Verified by ElevateAI',
              child: Icon(Icons.verified, color: Colors.blue, size: 20),
            ),
        ],
      ),
    );
  }
}
