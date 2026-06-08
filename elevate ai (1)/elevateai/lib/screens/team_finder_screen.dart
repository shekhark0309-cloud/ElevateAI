import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../flutter_integration.dart';
import '../widgets/team_match_card.dart';
import '../widgets/team_analysis_view.dart';
import '../models/team_analysis_model.dart';
import 'open_roles_screen.dart';

import '../widgets/team_match_card.dart';

class TeamFinderScreen extends StatefulWidget {
  const TeamFinderScreen({super.key});

  @override
  State<TeamFinderScreen> createState() => _TeamFinderScreenState();
}

class _TeamFinderScreenState extends State<TeamFinderScreen> {
  int _selectedTabIndex = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _myTeams = [];
  List<Map<String, dynamic>> _recommendedTeams = [];
  final _teamService = TeamService();

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
            .from('team_members')
            .select('*, teams(*)')
            .eq('student_id', user.id)
            .eq('status', 'active');

        final recommended = await _teamService.getTeamMatches(studentId: user.id);

        if (mounted) {
          setState(() {
            _myTeams = List<Map<String, dynamic>>.from(data);
            _recommendedTeams = List<Map<String, dynamic>>.from(recommended['data']['matches'] ?? []);
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

  void _openDebrief() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final res = await supabase
        .from('team_members')
        .select('team_id')
        .eq('student_id', user.id)
        .eq('status', 'active')
        .order('joined_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (res != null && mounted) {
      context.push('/post_hackathon/${res['team_id']}');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active team found.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Teams', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
          TextButton.icon(
            onPressed: _openDebrief,
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text('Debrief'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(child: _tabButton(0, 'My Teams')),
                  Expanded(child: _tabButton(1, 'Discover')),
                  Expanded(child: _tabButton(2, 'Find Roles')),
                ],
              ),
            ),
          ),
          Expanded(
            child: _selectedTabIndex == 0
              ? _buildMyTeamsList()
              : _selectedTabIndex == 1
                ? _buildRecommendedTeams()
                : const OpenRolesScreen(),
          ),
        ],
      ),
      bottomNavigationBar: _selectedTabIndex == 0 ? _buildCreateTeamButton() : null,
    );
  }

  Widget _buildCreateTeamButton() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('Create Team', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6200EE),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }

  Widget _buildMyTeamsList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_myTeams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('You are not in any teams yet.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: _myTeams.map((m) {
          final t = m['teams'];
          return _teamCard(
            id: t['id'],
            title: t['name'],
            status: t['status'].toString().toUpperCase(),
            members: 0, // In a real app, you'd fetch member count via RPC or join
            neededRoles: [],
            filledRoles: (t['required_skills'] as List? ?? []).map((s) => s.toString()).toList(),
            color: t['status'] == 'active' ? Colors.green : Colors.blue,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecommendedTeams() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_recommendedTeams.isEmpty) return const Center(child: Text('No team matches found yet. Try building your DNA!'));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _recommendedTeams.length,
      itemBuilder: (context, index) => TeamMatchCard(
        match: _recommendedTeams[index],
        onAdd: () {}, // Handle team application/join request
      ),
    );
  }

  Widget _tabButton(int index, String label) {
    final active = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF6200EE) : Colors.grey.shade600,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _teamCard({
    required String id,
    required String title,
    required String status,
    required int members,
    required List<String> neededRoles,
    required List<String> filledRoles,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (filledRoles.isNotEmpty) ...[
            const Text('SKILLS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filledRoles.map((r) => _roleTag(r, true)).toList(),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _analyzeTeam(id),
                  icon: const Icon(Icons.analytics_outlined, size: 18),
                  label: const Text('AI Health Analysis'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6200EE),
                    side: const BorderSide(color: Color(0xFF6200EE)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _analyzeTeam(String teamId) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => FutureBuilder(
        future: _teamService.analyzeTeam(teamId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 400, child: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError) {
            return SizedBox(height: 200, child: Center(child: Text('Error: ${snapshot.error}')));
          }
          final analysis = TeamAnalysis.fromJson(snapshot.data!);
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            expand: false,
            builder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              child: TeamAnalysisView(analysis: analysis),
            ),
          );
        },
      ),
    );
  }

  Widget _roleTag(String label, bool isFilled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isFilled ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: isFilled ? null : Border.all(color: Colors.indigo.shade100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: isFilled ? Colors.grey.shade700 : Colors.indigo,
          fontWeight: isFilled ? FontWeight.normal : FontWeight.bold,
        ),
      ),
    );
  }
}
