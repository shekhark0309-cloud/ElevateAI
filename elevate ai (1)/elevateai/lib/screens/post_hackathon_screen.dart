import 'package:flutter/material.dart';
import '../flutter_integration.dart';

class PostHackathonScreen extends StatefulWidget {
  final String teamId;
  const PostHackathonScreen({super.key, required this.teamId});

  @override
  State<PostHackathonScreen> createState() => _PostHackathonScreenState();
}

class _PostHackathonScreenState extends State<PostHackathonScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _members = [];
  final Map<String, Map<String, double>> _ratings = {};
  final Map<String, TextEditingController> _commentCtrl = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    for (var c in _commentCtrl.values) c.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final user = supabase.auth.currentUser;
      final res = await supabase.from('team_members').select('*, student_profiles(full_name)').eq('team_id', widget.teamId).eq('status', 'active');
      if (mounted) {
        setState(() {
          _members = List<Map<String, dynamic>>.from(res).where((m) => m['student_id'] != user?.id).toList();
          for (var m in _members) {
            final id = m['student_id'] as String;
            _ratings[id] = {'collaboration': 3.0, 'reliability': 3.0, 'communication': 3.0};
            _commentCtrl[id] = TextEditingController();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      for (var entry in _ratings.entries) {
        final rateeId = entry.key;
        final scores = entry.value;
        final overall = (scores['collaboration']! + scores['reliability']! + scores['communication']!) / 3;

        await supabase.rpc('submit_peer_rating', params: {
          'p_ratee_id': rateeId,
          'p_context_type': 'team',
          'p_context_id': widget.teamId,
          'p_overall': overall,
          'p_dimensions': scores,
          'p_comment': (_commentCtrl[rateeId]?.text.trim().isEmpty ?? true)
              ? 'Post-hackathon review'
              : _commentCtrl[rateeId]!.text.trim(),
        });
      }
      if (mounted) {
        // Trigger completion check
        supabase.functions.invoke('trigger-debrief-notifications', body: {
          'team_event_id': widget.teamId, // Using teamId as eventId for now as per current routing
          'action': 'check_completion',
        }).catchError((e) => debugPrint('Debrief trigger failed: $e'));

        _showSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Debrief Complete!'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('Your feedback helps build the TrustScore Network. Student DNA is being recalculated.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pushReplacementNamed(context, '/home'), child: const Text('Back to Home')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Team Peer Review')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _members.isEmpty
              ? const Center(child: Text('No teammates found to review.'))
              : _buildReviewList(),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SizedBox(
          height: 54,
          child: FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: Text(_isSubmitting ? 'SUBMITTING...' : 'SUBMIT REVIEWS'),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final m = _members[index];
        final id = m['student_id'];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m['student_profiles']['full_name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _ratingSlider(id, 'collaboration', 'Collaboration'),
            _ratingSlider(id, 'reliability', 'Reliability'),
            _ratingSlider(id, 'communication', 'Communication'),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: _commentCtrl[id],
                decoration: const InputDecoration(
                  labelText: 'Comment (optional)',
                  hintText: 'What did they do well?',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ),
            const Divider(height: 48),
          ],
        );
      },
    );
  }

  Widget _ratingSlider(String memberId, String dimension, String label) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(_ratings[memberId]![dimension]!.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: _ratings[memberId]![dimension]!,
          min: 1,
          max: 5,
          divisions: 4,
          onChanged: (v) => setState(() => _ratings[memberId]![dimension] = v),
        ),
      ],
    );
  }
}
