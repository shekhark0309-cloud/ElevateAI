import 'package:flutter/material.dart';
import '../flutter_integration.dart';
import '../widgets/loading_skeleton.dart';
import 'profile_detail_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _trustService = TrustScoreService();
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _leaderboard = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final collegeId = _tabController.index == 0 ? await _getCollegeId() : null;
      final data = await _trustService.getLeaderboard(collegeId: collegeId);
      if (mounted) {
        setState(() {
          _leaderboard = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<String?> _getCollegeId() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;
    final res = await supabase.from('student_profiles').select('college_id').eq('id', userId).single();
    return res['college_id'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trust Leaderboard'),
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => _loadData(),
          tabs: const [
            Tab(text: 'My College'),
            Tab(text: 'All India'),
          ],
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _buildLeaderboardList(),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: LoadingSkeleton(height: 70, width: double.infinity),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(child: Text(_errorMessage!));
  }

  Widget _buildLeaderboardList() {
    final currentUserId = supabase.auth.currentUser?.id;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _leaderboard.length,
        itemBuilder: (context, index) {
          final entry = _leaderboard[index];
          final isMe = entry['id'] == currentUserId || entry['full_name'] == supabase.auth.currentUser?.userMetadata?['full_name']; // Fallback check

          return Card(
            color: isMe ? Colors.indigo.withValues(alpha: 0.1) : null,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () {
                if (entry['id'] != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileDetailScreen(studentId: entry['id'])));
                }
              },
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  const CircleAvatar(child: Icon(Icons.person)),
                ],
              ),
              title: Text(entry['full_name'] ?? 'Anonymous'),
              subtitle: Row(
                children: [
                  Chip(
                    label: Text(entry['archetype'] ?? 'Discovering', style: const TextStyle(fontSize: 10)),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  Text(entry['college_short_name'] ?? '', style: const TextStyle(fontSize: 12)),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    (entry['overall_score'] as num).toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo),
                  ),
                  Text(entry['tier'] ?? 'Unverified', style: const TextStyle(fontSize: 10)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
