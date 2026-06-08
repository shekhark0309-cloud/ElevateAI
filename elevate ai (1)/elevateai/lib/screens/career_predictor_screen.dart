import 'dart:async';
import 'package:flutter/material.dart';
import '../flutter_integration.dart';
import '../services/erp_service.dart';

class CareerPredictorScreen extends StatefulWidget {
  const CareerPredictorScreen({super.key});

  @override
  State<CareerPredictorScreen> createState() => _CareerPredictorScreenState();
}

class _CareerPredictorScreenState extends State<CareerPredictorScreen> {
  final _dnaService = DNAService();
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _res;
  Map<String, dynamic>? _gaps;
  StreamSubscription? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();

    // Auto-refresh when ERP data is synced
    _syncSubscription = ERPService.onSyncComplete.listen((_) {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final res = await _dnaService.getPlacementScore(user.id);
        final gaps = await _dnaService.getCareerGaps(user.id);
        if (mounted) {
          setState(() {
            _res = res;
            _gaps = gaps;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Career Readiness Predictor')),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null
            ? Center(child: Text(_errorMessage!))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildScoreHero(),
                    const SizedBox(height: 32),
                    _buildSalaryPrediction(),
                    const SizedBox(height: 32),
                    _buildGapAnalysis(),
                    const SizedBox(height: 32),
                    _buildRoadmap(),
                  ],
                ),
              ),
    );
  }

  Widget _buildScoreHero() {
    final score = (_res?['placement_score'] as num?)?.toDouble() ?? 0.0;
    final readiness = _gaps?['readiness_label'] ?? 'DEVELOPING';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.purple[900]!, Colors.deepPurple[700]!]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text('PLACEMENT SCORE', style: TextStyle(color: Colors.white70, letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          Text('${score.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.w900)),
          Text('READINESS: $readiness', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSalaryPrediction() {
    final min = _res?['salary_min_lpa'] ?? 0;
    final max = _res?['salary_max_lpa'] ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PREDICTED SALARY RANGE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('₹$min–$max LPA', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(width: 12),
            const Icon(Icons.info_outline, color: Colors.grey, size: 16),
          ],
        ),
      ],
    );
  }

  Widget _buildGapAnalysis() {
    final gaps = (_gaps?['skill_gaps'] as List? ?? []);
    if (gaps.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SKILL GAPS FOR TARGET ROLE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
        const SizedBox(height: 16),
        ...gaps.map((g) => _gapTile(g['skill'], g['reason'])),
      ],
    );
  }

  Widget _gapTile(String skill, String reason) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(skill, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(reason, style: TextStyle(fontSize: 12, color: Colors.red[700])),
              ],
            ),
          ),
          TextButton(onPressed: () => Navigator.pushNamed(context, '/skill_reality'), child: const Text('ADD BADGE')),
        ],
      ),
    );
  }

  Widget _buildRoadmap() {
    final steps = (_gaps?['roadmap_steps'] as List? ?? []);
    if (steps.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('LEARNING ROADMAP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
        const SizedBox(height: 16),
        ...steps.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    s['status'] == 'done' ? Icons.check_circle : s['status'] == 'active' ? Icons.bolt : Icons.timer_outlined,
                    color: s['status'] == 'done' ? Colors.green : s['status'] == 'active' ? Colors.orange : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(s['step'], style: TextStyle(fontWeight: s['status'] == 'active' ? FontWeight.bold : FontWeight.normal))),
                ],
              ),
            )),
      ],
    );
  }
}
