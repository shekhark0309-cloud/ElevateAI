import 'package:flutter/material.dart';
import '../flutter_integration.dart';
import 'package:intl/intl.dart';

class ScamShieldScreen extends StatefulWidget {
  const ScamShieldScreen({super.key});

  @override
  State<ScamShieldScreen> createState() => _ScamShieldScreenState();
}

class _ScamShieldScreenState extends State<ScamShieldScreen> with SingleTickerProviderStateMixin {
  final _oppService = OpportunityService();
  final _scamService = ScamService();
  final _urlController = TextEditingController();
  final _descController = TextEditingController();
  late TabController _tabController;

  bool _isLoading = false;
  Map<String, dynamic>? _result;
  List<Map<String, dynamic>> _feed = [];
  bool _isLoadingFeed = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadFeed();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _descController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    setState(() => _isLoadingFeed = true);
    try {
      final data = await _scamService.getScamFeed();
      setState(() {
        _feed = data;
        _isLoadingFeed = false;
      });
    } catch (e) {
      setState(() => _isLoadingFeed = false);
    }
  }

  void _scan() async {
    setState(() => _isLoading = true);
    try {
      final res = await _oppService.scanForScam(
        title: 'User Manual Check',
        url: _urlController.text,
        description: _descController.text,
      );
      setState(() {
        _result = res['data'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ScamShield AI'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Scan'),
            Tab(text: 'Intelligence Feed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScanView(),
          _buildFeedView(),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: _showReportScamModal,
              icon: const Icon(Icons.report_problem_outlined),
              label: const Text('Report Scam'),
              backgroundColor: Colors.red[900],
            )
          : null,
    );
  }

  void _showReportScamModal() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'Fake Internship';
    String severity = 'medium';

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
              const Text('Report a Scam', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  'Fake Internship', 'Fake Scholarship', 'Fake Hackathon',
                  'Fake Job Offer', 'Fake Recruitment', 'Phishing Link',
                  'Payment Fraud', 'Telegram Scam', 'WhatsApp Scam',
                  'Social Engineering', 'Other'
                ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setModalState(() => category = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: severity,
                decoration: const InputDecoration(labelText: 'Severity'),
                items: ['low', 'medium', 'high', 'critical']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase())))
                    .toList(),
                onChanged: (v) => setModalState(() => severity = v!),
              ),
              const SizedBox(height: 16),
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Scam Title (e.g. Fake Google Internship)')),
              const SizedBox(height: 16),
              TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description / Evidence')),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () async {
                    if (titleCtrl.text.isEmpty) return;
                    await _scamService.reportScam(
                      category: category,
                      title: titleCtrl.text,
                      description: descCtrl.text,
                      severity: severity,
                    );
                    if (mounted) Navigator.pop(context);
                    _loadFeed();
                  },
                  style: FilledButton.styleFrom(backgroundColor: Colors.red[900]),
                  child: const Text('Submit Report'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Protect yourself from fake opportunities.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(labelText: 'Opportunity URL', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Description or Message', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _scan,
              icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
              label: const Text('Scan with ScamShield AI'),
              style: FilledButton.styleFrom(backgroundColor: Colors.red[900]),
            ),
          ),
          if (_result != null) _buildResult(),
        ],
      ),
    );
  }

  Widget _buildFeedView() {
    if (_isLoadingFeed) return const Center(child: CircularProgressIndicator());
    if (_feed.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFeed,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 400,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('No scams reported yet. Stay safe!', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFeed,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _feed.length,
        itemBuilder: (context, index) {
          final scam = _feed[index];
          return _buildScamCard(scam);
        },
      ),
    );
  }

  Widget _buildScamCard(Map<String, dynamic> scam) {
    final severity = scam['severity'] ?? 'medium';
    final status = scam['status'] ?? 'reported';
    final color = _getSeverityColor(severity);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: color),
                    const SizedBox(width: 8),
                    Text(
                      severity.toString().toUpperCase(),
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ],
                ),
                Text(
                  DateFormat.yMMMd().format(DateTime.parse(scam['created_at'])),
                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scam['title'] ?? 'Untitled Scam',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  scam['category'] ?? 'Other',
                  style: TextStyle(color: Colors.indigo[700], fontWeight: FontWeight.w500, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Text(
                  scam['description'] ?? '',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[800], fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status.toString().replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(color: Colors.grey[700], fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (scam['is_trending'] == true)
                      const Row(
                        children: [
                          Icon(Icons.trending_up, size: 14, color: Colors.orange),
                          SizedBox(width: 4),
                          Text('TRENDING', style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical': return Colors.red[900]!;
      case 'high': return Colors.red;
      case 'medium': return Colors.orange;
      case 'low': return Colors.blue;
      default: return Colors.grey;
    }
  }

  Widget _buildResult() {
    final score = (_result?['risk_score'] as num?)?.toDouble() ?? 0.0;
    final level = _result?['risk_level'] ?? 'Unknown';
    final isSafe = score < 40;

    return Column(
      children: [
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isSafe ? Colors.green[50] : Colors.red[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSafe ? Colors.green : Colors.red),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('RISK SCORE: ${score.toInt()}/100', style: TextStyle(fontWeight: FontWeight.bold, color: isSafe ? Colors.green : Colors.red)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: isSafe ? Colors.green : Colors.red, borderRadius: BorderRadius.circular(4)),
                    child: Text(level.toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _result?['explanation'] ?? 'Analysis complete.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Text(
                'Recommendation: ${_result?['recommendation']}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
