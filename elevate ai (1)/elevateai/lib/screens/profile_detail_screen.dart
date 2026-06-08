import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../flutter_integration.dart';

class ProfileDetailScreen extends StatefulWidget {
  final String? studentId;
  const ProfileDetailScreen({super.key, this.studentId});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  final _skillsService = SkillsService();
  final _trustService = TrustScoreService();
  bool _isLoading = true;
  bool _isVariantB = false;
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _skills = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = supabase.auth.currentUser;
      final targetId = widget.studentId ?? user?.id;

      if (targetId != null) {
        // 1. Fetch Profile + Trust + DNA
        final profile = await supabase
            .from('student_profiles')
            .select('*, trust_scores(*), student_dna(*)')
            .eq('id', targetId)
            .single();

        // 2. Fetch Skills
        final skills = await _skillsService.getStudentSkills(targetId);

        if (mounted) {
          setState(() {
            _profileData = profile;
            _skills = skills;
            _isLoading = false;
          });
        }
      } else {
        // Test Mode Fallback
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final name = _profileData?['full_name'] ?? 'Elevate Student';
    final trustData = _profileData?['trust_scores'] ?? {};
    final trustScore = (trustData['overall_score'] as num?)?.toDouble() ?? 8.7;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Switch(
            value: _isVariantB,
            onChanged: (v) => setState(() => _isVariantB = v),
            activeColor: const Color(0xFF6200EE),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildProfileHeader(name, trustScore),
            const SizedBox(height: 24),
            if (widget.studentId != null && widget.studentId != supabase.auth.currentUser?.id)
              _buildConnectionActions(),
            const SizedBox(height: 24),
            _buildReliabilityIntelligence(trustScore),
            const SizedBox(height: 24),
            _buildVerificationBanner(),
            const SizedBox(height: 32),
            _buildSkillsSection(),
            const SizedBox(height: 32),
            if (!_isVariantB) ...[
              _buildWorkStyleIdentity(),
              const SizedBox(height: 32),
              _buildPortfolioPreview(),
              const SizedBox(height: 40),
              _buildOneClickResumeCTA(),
            ] else ...[
              _buildPortfolioGallery(),
              const SizedBox(height: 32),
              _buildPublicUrlField(),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String name, double score) {
    final major = _profileData?['course'] ?? 'AI & Data Science';
    final year = _profileData?['year_of_study'] ?? 3;
    final college = 'IIT Bombay'; // Can be fetched from college_id later if needed

    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.grey,
          backgroundImage: _profileData?['avatar_url'] != null
              ? NetworkImage(_profileData!['avatar_url'])
              : const NetworkImage('https://i.pravatar.cc/150?img=12'),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text('$major • Year $year', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              Text(college, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.verified, color: Colors.blue.shade400, size: 16),
                  const SizedBox(width: 4),
                  Text('Verified', style: TextStyle(color: Colors.blue.shade400, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        Column(
          children: [
            const Text('TrustScore', style: TextStyle(color: Colors.grey, fontSize: 11)),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.amber.shade50, shape: BoxShape.circle),
              child: Text(
                score.toStringAsFixed(1),
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReliabilityIntelligence(double trustScore) {
    // Calculate skill score: avg proficiency * 20
    double skillScore = 0;
    if (_skills.isNotEmpty) {
      final total = _skills.fold<int>(0, (sum, s) => sum + (s['proficiency'] as int? ?? 0));
      skillScore = (total / _skills.length) * 20;
    } else {
      skillScore = 60; // neutral default if no skills listed yet
    }

    final insight = _trustService.analyzeReliability(trustScore * 10, skillScore);
    final color = _getColor(insight['color']);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(insight['is_warning'] ? Icons.warning_amber_rounded : Icons.verified_user_outlined, color: color),
              const SizedBox(width: 12),
              Text(
                insight['status'].toString().toUpperCase(),
                style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 1.1, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight['explanation'],
            style: const TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          const Text('RELIABILITY INDICATORS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 12),
          _indicatorRow('Attendance', '92%', true),
          _indicatorRow('Task Completion', '87%', true),
          _indicatorRow('Peer Collaboration', trustScore > 7 ? 'High' : 'Improving', trustScore > 5),
        ],
      ),
    );
  }

  Widget _indicatorRow(String label, String val, bool isPositive) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
          Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isPositive ? Colors.green : Colors.orange)),
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

  Widget _buildVerificationBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 12),
          Text(
            'Verified by ElevateAI • Academic Record Synced',
            style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsSection() {
    if (_skills.isEmpty && !(_profileData == null)) return const SizedBox.shrink();

    final displaySkills = _skills.isNotEmpty
        ? _skills
        : [
            {'skill_name': 'Python', 'proficiency': 4},
            {'skill_name': 'SQL', 'proficiency': 3},
            {'skill_name': 'Machine Learning', 'proficiency': 4},
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Skills (Verified)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(onPressed: () {}, child: const Text('Add Skills')),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: displaySkills.map((s) => _skillChip(s['skill_name'], s['proficiency'])).toList(),
        ),
      ],
    );
  }

  Widget _skillChip(String label, int proficiency) {
    String level = 'Beginner';
    if (proficiency >= 4) level = 'Advanced';
    else if (proficiency >= 3) level = 'Intermediate';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(level, style: TextStyle(color: level == 'Advanced' ? Colors.green : Colors.grey, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildWorkStyleIdentity() {
    final dna = _profileData?['student_dna'] ?? {};
    final trust = _profileData?['trust_scores'] ?? {};

    // Map trust scores to radar dimensions
    final reliability = (trust['reliability_score'] as num?)?.toDouble() ?? 80.0;
    final collaboration = (trust['collaboration_score'] as num?)?.toDouble() ?? 60.0;
    final integrity = (trust['integrity_score'] as num?)?.toDouble() ?? 90.0;
    final competency = (trust['skill_validation_score'] as num?)?.toDouble() ?? 70.0;
    final social = (trust['community_score'] as num?)?.toDouble() ?? 50.0;

    final radarScores = [reliability / 100, collaboration / 100, integrity / 100, competency / 100, social / 100, 0.7];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Work Style Identity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/dna_quiz'),
                child: const Text('Retake Test', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CustomPaint(painter: RadarChartPainter(scores: radarScores)),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _archetypeRow('Reliability', reliability.toInt(), Colors.indigo),
                    _archetypeRow('Collaboration', collaboration.toInt(), Colors.purple),
                    _archetypeRow('Integrity', integrity.toInt(), Colors.teal),
                    _archetypeRow('Competency', competency.toInt(), Colors.orange),
                  ],
                ),
              ),
            ],
          ),
          if (dna['ai_summary'] != null) ...[
            const SizedBox(height: 24),
            const Text('AI INSIGHTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(dna['ai_summary'], style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _archetypeRow(String label, int val, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              Text('$val%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: val / 100,
            backgroundColor: color.withOpacity(0.1),
            color: color,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Portfolio Preview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.picture_as_pdf, color: Colors.indigo),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Master Resume 2024', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Last updated 2 days ago', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Generate PDF'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text('Share Link'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortfolioGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Digital Portfolio Gallery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _galleryItem('https://images.unsplash.com/photo-1586281380349-632531db7ed4?q=80&w=2070', 'Technical Resume')),
            const SizedBox(width: 16),
            Expanded(child: _galleryItem('https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=1964', 'Project Paper')),
          ],
        ),
      ],
    );
  }

  Widget _galleryItem(String url, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildPublicUrlField() {
    final name = _profileData?['full_name']?.toString().toLowerCase().replaceAll(' ', '') ?? 'student';
    final url = 'elevateai.com/$name';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Portfolio Link', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.link, color: Colors.grey, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(url, style: const TextStyle(fontWeight: FontWeight.w500))),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: 'https://$url'));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied to clipboard!')));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOneClickResumeCTA() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.bolt),
        label: const Text('One-Click Resume', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF6200EE),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildConnectionActions() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Connect'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6200EE),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final chatService = ChatService();
              final convId = await chatService.getOrCreateConversation(widget.studentId!);
              if (mounted) {
                context.push('/chat/$convId?name=${_profileData?['full_name']}');
              }
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Message'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF6200EE)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

class RadarChartPainter extends CustomPainter {
  final List<double> scores;
  RadarChartPainter({required this.scores});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 1; i <= 3; i++) {
      final r = radius * (i / 3);
      final path = Path();
      for (var j = 0; j < 6; j++) {
        final angle = (j * 60) * math.pi / 180;
        final x = center.dx + r * math.cos(angle);
        final y = center.dy + r * math.sin(angle);
        if (j == 0) path.moveTo(x, y); else path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, paint);
    }

    final activePaint = Paint()..color = const Color(0xFF6200EE).withOpacity(0.3);
    final activeBorder = Paint()..color = const Color(0xFF6200EE)..style = PaintingStyle.stroke..strokeWidth = 2;
    final activePath = Path();

    for (var i = 0; i < 6; i++) {
      final r = radius * (i < scores.length ? scores[i] : 0.5);
      final angle = (i * 60) * math.pi / 180;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) activePath.moveTo(x, y); else activePath.lineTo(x, y);
    }
    activePath.close();
    canvas.drawPath(activePath, activePaint);
    canvas.drawPath(activePath, activeBorder);
  }

  @override
  bool shouldRepaint(covariant RadarChartPainter oldDelegate) => oldDelegate.scores != scores;
}
