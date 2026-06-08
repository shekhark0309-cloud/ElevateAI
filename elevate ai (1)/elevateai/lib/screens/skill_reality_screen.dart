import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../flutter_integration.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/trust_score_ring.dart';

class SkillRealityScreen extends StatefulWidget {
  const SkillRealityScreen({super.key});

  @override
  State<SkillRealityScreen> createState() => _SkillRealityScreenState();
}

class _SkillRealityScreenState extends State<SkillRealityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _skillsService = SkillsService();
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _allBadges = [];
  List<Map<String, dynamic>> _myBadges = [];

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
      final res = await supabase.from('skill_badges').select().eq('is_active', true);
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final mine = await supabase.from('student_badges').select('*, skill_badges(*)').eq('student_id', userId);
        if (mounted) {
          setState(() {
            _allBadges = List<Map<String, dynamic>>.from(res);
            _myBadges = List<Map<String, dynamic>>.from(mine);
            _isLoading = false;
          });
        }
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

  void _showBadgeDetail(Map<String, dynamic> b) async {
    // 1. Check if AI challenge exists for this badge
    final challengeRes = await supabase
        .from('skill_challenges')
        .select()
        .eq('badge_id', b['id'])
        .eq('is_active', true)
        .maybeSingle();

    if (challengeRes != null) {
      _showChallengeDialog(b, challengeRes);
    } else {
      // Fallback to peer review flow
      _showPeerReviewModal(b);
    }
  }

  void _showPeerReviewModal(Map<String, dynamic> b) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(b['name'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Chip(label: Text(b['category'].toString().toUpperCase()), backgroundColor: Colors.amber.withOpacity(0.1)),
            const SizedBox(height: 24),
            const Text('PEER REVIEW CHALLENGE:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Text(b['description'] ?? 'Complete a project and get it verified by 3 peers to earn this badge.'),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () => _startPeerChallenge(b['id']),
                child: const Text('Start Peer Review Flow'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startPeerChallenge(String badgeId) async {
    final userId = supabase.auth.currentUser!.id;
    try {
      await _skillsService.awardBadge(studentId: userId, badgeId: badgeId, autoVerify: false);
      _loadData();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submission sent for peer review!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _showChallengeDialog(Map<String, dynamic> badge, Map<String, dynamic> challenge) {
    final codeController = TextEditingController(text: challenge['starter_code'] ?? '');
    int secondsRemaining = (challenge['time_limit_minutes'] ?? 30) * 60;
    Timer? timer;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (secondsRemaining > 0) {
              setState(() => secondsRemaining--);
            } else {
              t.cancel();
            }
          });

          final minutes = (secondsRemaining / 60).floor();
          final seconds = secondsRemaining % 60;

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(challenge['title'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        '$minutes:${seconds.toString().padLeft(2, '0')}',
                        style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('PROBLEM STATEMENT:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                Text(challenge['problem_statement']),
                const SizedBox(height: 24),
                const Text('YOUR SOLUTION:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                Expanded(
                  child: TextField(
                    controller: codeController,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                    decoration: InputDecoration(
                      fillColor: Colors.grey.shade50,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: () {
                      timer?.cancel();
                      _submitChallenge(challenge['id'], codeController.text);
                    },
                    child: const Text('Submit for AI Evaluation'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) => timer?.cancel());
  }

  Future<void> _submitChallenge(String challengeId, String code) async {
    final studentId = supabase.auth.currentUser!.id;

    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 24),
                Text('Claude is evaluating your code...', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // 1. Create attempt
      final attempt = await supabase
          .from('challenge_attempts')
          .insert({
            'student_id': studentId,
            'challenge_id': challengeId,
            'submitted_code': code,
            'status': 'submitted'
          })
          .select()
          .single();

      // 2. Invoke Edge Function
      final res = await supabase.functions.invoke('evaluate-challenge', body: {
        'student_id': studentId,
        'attempt_id': attempt['id'],
      });

      if (mounted) Navigator.pop(context); // Close loading
      if (mounted) Navigator.pop(context); // Close challenge modal

      if (res.status == 200) {
        final data = res.data['data'];
        _showEvaluationResult(data);
        _loadData();
      } else {
        throw Exception(res.data['error'] ?? 'Evaluation failed');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _showEvaluationResult(Map<String, dynamic> data) {
    final score = data['score'] as int;
    final passed = data['passed'] as bool;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(passed ? '🎉 CHALLENGE PASSED!' : '⏳ CHALLENGE FAILED',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: passed ? Colors.green : Colors.orange)),
            const SizedBox(height: 32),
            SizedBox(
              height: 120,
              width: 120,
              child: TrustScoreRing(score: score.toDouble(), tier: 'Evaluating'),
            ),
            const SizedBox(height: 24),
            Text(data['feedback'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            if (data['improvement_tips'] != null) ...[
              const Align(alignment: Alignment.centerLeft, child: Text('IMPROVEMENT TIPS:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
              const SizedBox(height: 12),
              ...(data['improvement_tips'] as List).map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(children: [const Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber), const SizedBox(width: 8), Expanded(child: Text(tip))]),
              )),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skill Reality Badges'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Available'),
            Tab(text: 'My Badges'),
          ],
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAvailableTab(),
                    _buildMyBadgesTab(),
                  ],
                ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: LoadingSkeleton(height: 100, width: double.infinity),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(child: Text(_errorMessage!));
  }

  Widget _buildAvailableTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allBadges.length,
      itemBuilder: (context, index) {
        final b = _allBadges[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: Colors.indigo.withOpacity(0.1), child: const Icon(Icons.badge, color: Colors.indigo)),
            title: Text(b['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(b['description'] ?? ''),
            trailing: Text('${b['xp_value']} XP', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
            onTap: () => _showBadgeDetail(b),
          ),
        );
      },
    );
  }

  Widget _buildMyBadgesTab() {
    if (_myBadges.isEmpty) {
      return const Center(child: Text('No badges earned yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myBadges.length,
      itemBuilder: (context, index) {
        final mb = _myBadges[index];
        final b = mb['skill_badges'];
        final status = mb['verify_status'];
        final color = status == 'verified' ? Colors.green : status == 'pending' ? Colors.orange : Colors.red;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(Icons.verified, color: color)),
            title: Text(b['name']),
            subtitle: Text('Status: ${status.toString().toUpperCase()}'),
            trailing: status == 'pending'
                ? TextButton(
                    onPressed: () => context.push('/campus_connect', extra: {'badge_id': b['id']}),
                    child: const Text('FIND PEER'),
                  )
                : null,
          ),
        );
      },
    );
  }
}
