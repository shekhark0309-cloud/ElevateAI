import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../flutter_integration.dart';
import '../widgets/loading_skeleton.dart';
import '../services/chat_service.dart';
import '../services/team_service.dart';
import '../models/team_analysis_model.dart';
import 'profile_detail_screen.dart';

class OpenRolesScreen extends StatefulWidget {
  const OpenRolesScreen({super.key});

  @override
  State<OpenRolesScreen> createState() => _OpenRolesScreenState();
}

class _OpenRolesScreenState extends State<OpenRolesScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _myPostings = [];
  int _tabIndex = 0;
  late TabController _tabController;
  final _trustService = TrustScoreService();
  final _teamService = TeamService();

  final _titleCtrl  = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _domainCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();

  List<Map<String, dynamic>> _userTeams = [];
  String? _selectedTeamId;
  TeamAnalysis? _aiSuggestion;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _domainCtrl.dispose();
    _skillsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      final res = await supabase.from('role_postings').select('*, student_profiles(full_name), teams(name)').eq('status', 'open');

      List<Map<String, dynamic>> myPostings = [];
      if (user != null) {
        myPostings = await supabase.from('role_postings').select('*, role_applications(*, student_profiles(*, trust_scores(*)))').eq('creator_id', user.id);

        final teamsRes = await supabase
            .from('team_members')
            .select('team_id, teams(id, name)')
            .eq('student_id', user.id)
            .eq('status', 'active');
        _userTeams = List<Map<String, dynamic>>.from(teamsRes);
      }

      if (mounted) {
        setState(() {
          _roles = List<Map<String, dynamic>>.from(res);
          _myPostings = List<Map<String, dynamic>>.from(myPostings);
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

  Future<void> _apply(String postingId) async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        await supabase.from('role_applications').insert({
          'posting_id': postingId,
          'applicant_id': user.id,
          'message': 'Interested in this role!',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted!')));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Roles'),
        bottom: TabBar(
          controller: _tabController,
          onTap: (i) => setState(() => _tabIndex = i),
          tabs: const [Tab(text: 'Find Roles'), Tab(text: 'My Postings')],
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _tabIndex == 0
                ? _buildRolesList()
                : _buildMyPostings(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPostRoleModal,
        label: const Text('Post a Role'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: LoadingSkeleton(height: 120, width: double.infinity),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(child: Text(_errorMessage!));
  }

  Widget _buildRolesList() {
    if (_roles.isEmpty) return const Center(child: Text('No open roles found.'));

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _roles.length,
        itemBuilder: (context, index) {
          final r = _roles[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(r['role_title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Chip(label: Text(r['domain'] ?? 'Tech'), visualDensity: VisualDensity.compact),
                    ],
                  ),
                  Text('Team: ${r['teams']?['name'] ?? 'Startup'}', style: const TextStyle(color: Colors.indigo)),
                  const SizedBox(height: 8),
                  Text(r['description'] ?? ''),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: (r['required_skills'] as List).map((s) => Chip(label: Text(s), side: BorderSide.none, backgroundColor: Colors.grey[100])).toList(),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('By ${r['student_profiles']?['full_name']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () async {
                              final chatService = ChatService();
                              final convId = await chatService.getOrCreateConversation(r['creator_id']);
                              if (mounted) context.push('/chat/$convId?name=${r['student_profiles']?['full_name']}');
                            },
                            icon: const Icon(Icons.chat_bubble_outline, color: Colors.indigo),
                          ),
                          ElevatedButton(onPressed: () => _apply(r['id']), child: const Text('APPLY')),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMyPostings() {
    if (_myPostings.isEmpty) return const Center(child: Text('You haven\'t posted any roles yet.'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myPostings.length,
      itemBuilder: (context, index) {
        final p = _myPostings[index];
        final apps = p['role_applications'] as List? ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p['role_title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Applicants (${apps.length})', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 12),
            ...apps.map((a) => _applicantCard(a)).toList(),
            const Divider(height: 40),
          ],
        );
      },
    );
  }

  Widget _applicantCard(Map<String, dynamic> app) {
    final profile = app['student_profiles'] ?? {};
    final trust = profile['trust_scores'] ?? {};
    final trustScore = (trust['overall_score'] as num?)?.toDouble() ?? 5.0;

    // Skill score estimation for reliability analysis
    final skillScore = 70.0; // In a real app, calculate from actual skills
    final insight = _trustService.analyzeReliability(trustScore * 10, skillScore);
    final color = _getColor(insight['color']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withOpacity(0.2))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(profile['full_name']?[0] ?? 'S')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile['full_name'] ?? 'Student', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('TrustScore: ${trustScore.toStringAsFixed(1)}/10', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                _reliabilityBadge(insight),
              ],
            ),
            const SizedBox(height: 12),
            if (app['message'] != null) Text('"${app['message']}"', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileDetailScreen(studentId: app['applicant_id']))),
                  child: const Text('VIEW PROFILE'),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () async {
                    final chatService = ChatService();
                    final convId = await chatService.getOrCreateConversation(app['applicant_id']);
                    if (mounted) context.push('/chat/$convId?name=${profile['full_name']}');
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: () {}, child: const Text('SHORTLIST')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _reliabilityBadge(Map<String, dynamic> insight) {
    final color = _getColor(insight['color']);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(insight['is_warning'] ? Icons.warning_amber_rounded : Icons.verified_user, size: 12, color: color),
          const SizedBox(width: 4),
          Text(insight['status'], style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
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

  void _showPostRoleModal() {
    _aiSuggestion = null;
    _selectedTeamId = null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Post an Open Role', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (_userTeams.isNotEmpty) ...[
                const Text('SELECT TEAM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedTeamId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  hint: const Text('Select a team to get AI suggestions'),
                  items: _userTeams.map((t) => DropdownMenuItem(
                    value: t['teams']['id'] as String,
                    child: Text(t['teams']['name'] as String),
                  )).toList(),
                  onChanged: (val) async {
                    setModalState(() {
                      _selectedTeamId = val;
                      _isAnalyzing = true;
                    });
                    try {
                      final data = await _teamService.analyzeTeam(val!);
                      final analysis = TeamAnalysis.fromJson(data);
                      setModalState(() {
                        _aiSuggestion = analysis;
                        _isAnalyzing = false;
                        if (analysis.missingRoles.isNotEmpty) {
                          _titleCtrl.text = analysis.missingRoles.first;
                          _descCtrl.text = "Join our team! We need help with ${analysis.missingRoles.first}. AI Analysis: ${analysis.teamStrengthSummary}";
                        }
                      });
                    } catch (e) {
                      setModalState(() => _isAnalyzing = false);
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],
              if (_isAnalyzing)
                const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
              else if (_aiSuggestion != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.indigo.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.indigo, size: 16),
                          const SizedBox(width: 8),
                          const Text('AI Suggestion', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12)),
                          const Spacer(),
                          Text('Health Score: ${_aiSuggestion!.healthScore}', style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _aiSuggestion!.reasoning,
                        style: const TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Role Title')),
              const SizedBox(height: 16),
              TextField(controller: _domainCtrl, decoration: const InputDecoration(labelText: 'Domain (e.g. Fintech)')),
              const SizedBox(height: 16),
              TextField(controller: _descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 16),
              TextField(
                controller: _skillsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Required Skills (comma-separated)',
                  hintText: 'React, Node.js, Figma',
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () async {
                    final user = supabase.auth.currentUser;
                    if (user != null) {
                      await supabase.from('role_postings').insert({
                        'creator_id': user.id,
                        'team_id': _selectedTeamId,
                        'role_title': _titleCtrl.text,
                        'description': _descCtrl.text,
                        'domain': _domainCtrl.text,
                        'required_skills': _skillsCtrl.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList(),
                      });
                      _titleCtrl.clear();
                      _descCtrl.clear();
                      _domainCtrl.clear();
                      _skillsCtrl.clear();
                      _loadData();
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Post Role'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
