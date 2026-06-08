import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../flutter_integration.dart';
import '../models/idea_models.dart';
import '../widgets/trust_score_ring.dart';

class IdeaDetailsScreen extends StatefulWidget {
  final String ideaId;
  const IdeaDetailsScreen({super.key, required this.ideaId});

  @override
  State<IdeaDetailsScreen> createState() => _IdeaDetailsScreenState();
}

class _IdeaDetailsScreenState extends State<IdeaDetailsScreen> {
  final _innovationService = InnovationService();
  final _chatService = ChatService();
  bool _isLoading = true;
  ProjectIdea? _idea;
  List<Map<String, dynamic>> _openRoles = [];
  Map<String, dynamic>? _creatorProfile;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final data = await supabase.from('project_ideas').select().eq('id', widget.ideaId).single();
      final roles = await _innovationService.getOpenRoles(widget.ideaId);
      final creator = await supabase.from('student_profiles').select('*, trust_scores(*)').eq('id', data['creator_id']).single();

      if (mounted) {
        setState(() {
          _idea = ProjectIdea.fromJson(data);
          _openRoles = roles;
          _creatorProfile = creator;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_idea == null) return const Scaffold(body: Center(child: Text('Idea not found.')));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Idea Details', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildSectionTitle('Problem Statement'),
            const SizedBox(height: 8),
            Text(_idea!.problemStatement ?? 'Not defined.', style: const TextStyle(fontSize: 15, color: Colors.black87)),
            const SizedBox(height: 24),
            _buildSectionTitle('Proposed Solution'),
            const SizedBox(height: 8),
            Text(_idea!.solution ?? 'Not defined.', style: const TextStyle(fontSize: 15, color: Colors.black87)),
            const SizedBox(height: 32),
            _buildAIInsights(),
            const SizedBox(height: 32),
            _buildSectionTitle('Open Roles'),
            const SizedBox(height: 16),
            _buildRolesList(),
            const SizedBox(height: 32),
            _buildCreatorCard(),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: _buildActionButtons(),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF6200EE).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(_idea!.category ?? 'Project', style: const TextStyle(color: Color(0xFF6200EE), fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const Spacer(),
            Text('Stage: ${_idea!.stage.toUpperCase()}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 16),
        Text(_idea!.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: _idea!.tags.map((t) => Chip(label: Text(t), visualDensity: VisualDensity.compact)).toList(),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildAIInsights() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.amber.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amber),
              const SizedBox(width: 12),
              const Text('AI Innovation Score', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              Text('${_idea!.innovationScore ?? 0}/10', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
          const Divider(height: 24),
          _insightRow('Feasibility', '${_idea!.feasibilityScore ?? 0}/10'),
          _insightRow('Market Potential', _idea!.marketPotential ?? 'N/A'),
          _insightRow('Complexity', _idea!.technicalComplexity ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _insightRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildRolesList() {
    if (_openRoles.isEmpty) return const Text('No open roles currently.', style: TextStyle(color: Colors.grey));

    return Column(
      children: _openRoles.map((role) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          title: Text(role['role_title'], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(List<String>.from(role['required_skills'] ?? []).join(', ')),
          trailing: FilledButton(
            onPressed: () => _applyForRole(role['id']),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6200EE)),
            child: const Text('Apply'),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildCreatorCard() {
    if (_creatorProfile == null) return const SizedBox.shrink();
    final name = _creatorProfile!['full_name'];
    final trust = _creatorProfile!['trust_scores']?['overall_score'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CREATOR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: _creatorProfile!['avatar_url'] != null ? NetworkImage(_creatorProfile!['avatar_url']) : null,
                child: _creatorProfile!['avatar_url'] == null ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${_creatorProfile!['course']} • Year ${_creatorProfile!['year_of_study']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Column(
                children: [
                  const Text('TRUST', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                  Text(trust.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _messageCreator(),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Message'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                minimumSize: const Size(0, 56),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              onPressed: () => _joinIdea(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6200EE),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                minimumSize: const Size(0, 56),
              ),
              child: const Text('Join Team', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _messageCreator() async {
    final creatorId = _idea!.creatorId;
    final convId = await _chatService.getOrCreateConversation(creatorId);
    if (mounted) {
      context.push('/chat/$convId?name=${_creatorProfile!['full_name']}');
    }
  }

  void _joinIdea() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      await _innovationService.joinIdea(_idea!.id, user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent to join team!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error joining: $e')));
    }
  }

  void _applyForRole(String roleId) {
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application sent for role!')));
  }
}
