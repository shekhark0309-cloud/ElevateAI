import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../flutter_integration.dart';
import '../services/erp_service.dart';
import '../models/nudge_model.dart';
import '../services/native_navigation_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _dashboardService = DashboardService();
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _data;
  StreamSubscription? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();

    // Listen for ERP sync events to auto-refresh dashboard
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final data = await _dashboardService.getDashboard(user.id);
        if (mounted) {
          setState(() {
            _data = data;
            _isLoading = false;
          });
        }
      } else {
        // Fallback for guest or slow auth
        if (mounted) setState(() => _isLoading = false);
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
    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildHeader(),
                const SizedBox(height: 24),
                _buildTrustScoreCard(),
                const SizedBox(height: 24),
                _buildERPSyncCard(),
                const SizedBox(height: 24),
                _buildResumeWidget(),
                const SizedBox(height: 24),
                _buildScamAlerts(),
                const SizedBox(height: 24),
                _buildSustainabilityWidget(),
                const SizedBox(height: 24),
                _buildSmartNudges(),
                const SizedBox(height: 24),
                _buildFocusSection(),
                const SizedBox(height: 32),
                _buildQuickActions(),
                const SizedBox(height: 32),
                _buildUpcomingSection(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final profile = _data?['profile'] ?? {};
    final name = profile['full_name'] ?? 'Student';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, ${name.split(' ')[0]} 👋',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Ready to elevate today?',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: () => NativeNavigationService.openOSDashboard(),
              icon: const Icon(Icons.dashboard_customize_outlined, color: Color(0xFF6200EE)),
              tooltip: 'Open OS Command Center',
            ),
            IconButton(
              onPressed: () => context.push('/conversations'),
              icon: const Icon(Icons.chat_bubble_outline, size: 26),
            ),
            Stack(
              children: [
                IconButton(
                  onPressed: () => context.push('/notifications'),
                  icon: const Icon(Icons.notifications_outlined, size: 28),
                ),
                if ((_data?['unread_notifications'] as List? ?? []).isNotEmpty)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrustScoreCard() {
    final trust = _data?['trust'] ?? {};
    final score = trust['overall_score'] as num?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.amber.shade50, shape: BoxShape.circle),
            child: const Icon(Icons.verified_user, color: Colors.amber, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TrustScore', style: TextStyle(color: Colors.grey, fontSize: 14)),
              Text(
                score != null ? '${score.toDouble().toStringAsFixed(1)} / 10' : 'Syncing...',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
            child: const Row(
              children: [
                Icon(Icons.trending_up, color: Colors.green, size: 14),
                SizedBox(width: 4),
                Text('Real-time', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildERPSyncCard() {
    final academic = _data?['academic_snapshot'] ?? {};
    final isSynced = academic['synced'] ?? false;
    final lastSync = academic['last_sync'] != null ? DateTime.parse(academic['last_sync'] as String) : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSynced ? [const Color(0xFF6200EE), const Color(0xFF7C4DFF)] : [Colors.grey.shade100, Colors.grey.shade200],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: isSynced ? [BoxShadow(color: const Color(0xFF6200EE).withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))] : [],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: Icon(isSynced ? Icons.account_balance : Icons.cloud_off, color: isSynced ? Colors.white : Colors.grey, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSynced ? 'College ERP Synced' : 'Sync College Records',
                      style: TextStyle(color: isSynced ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      isSynced ? 'Academic snapshot active' : 'Import your CGPA & Attendance',
                      style: TextStyle(color: isSynced ? Colors.white70 : Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (!isSynced)
                TextButton(
                  onPressed: _syncERP,
                  style: TextButton.styleFrom(backgroundColor: const Color(0xFF6200EE), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('SYNC'),
                )
              else
                IconButton(
                  onPressed: _syncERP,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Resync',
                ),
            ],
          ),
          if (isSynced) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _academicStat('CGPA', academic['cgpa'].toString(), Colors.white),
                _academicStat('Attendance', '${academic['attendance']}%', Colors.white),
                _academicStat('Progress', '${academic['progress']}%', Colors.white),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _academicStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
      ],
    );
  }

  Future<void> _syncERP() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

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
                Text('Syncing with Institutional ERP...', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Verifying academic reliability...', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final erpService = ERPService();
      // Fetch college_id from profile
      final profile = await supabase.from('student_profiles').select('college_id').eq('id', user.id).single();
      final collegeId = profile['college_id'] ?? 'c1000000-0000-0000-0000-000000000001';

      await erpService.syncCollegeRecords(user.id, collegeId);

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Academic records synced successfully!')));
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync Failed: $e')));
      }
    }
  }

  Widget _buildResumeWidget() {
    final portfolio = _data?['portfolio_center'] ?? {};
    final latest = portfolio['latest_resume'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Portfolio AI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('${portfolio['completion'] ?? 0}% Complete', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          if (latest != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Latest Resume (v${latest['version']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Generated: ${latest['created_at'].toString().substring(0, 10)}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => launchUrl(Uri.parse(latest['pdf_url'])),
                    icon: const Icon(Icons.open_in_new, size: 20),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Text('No resume generated yet. Let AI build one for you.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/portfolio'),
              icon: const Icon(Icons.bolt, size: 18),
              label: const Text('Go to Portfolio Hub'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.indigo,
                side: const BorderSide(color: Colors.indigo),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScamAlerts() {
    final alerts = _data?['scam_alerts'] as List? ?? [];
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Community Scam Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
            TextButton(onPressed: () => context.push('/scam_shield'), child: const Text('View Feed')),
          ],
        ),
        ...alerts.map((a) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade100),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${a['category']} • ${a['severity'].toString().toUpperCase()}', style: TextStyle(color: Colors.red.shade900, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.red, size: 16),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildSustainabilityWidget() {
    final sustainability = _data?['sustainability'] ?? {};
    final meals = sustainability['meals_saved'] ?? 0;

    return InkWell(
      onTap: () => context.push('/sustainability'),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.shade600,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.eco, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sustainability Impact', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('You have saved $meals meals! See your full impact.', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartNudges() {
    final nudges = _data?['smart_nudges'] as List<dynamic>? ?? [];
    if (nudges.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Today's Recommendations", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(
          height: 170,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: nudges.length,
            itemBuilder: (context, index) {
              final nudge = nudges[index] as SmartNudge;
              return _nudgeCard(nudge);
            },
          ),
        ),
      ],
    );
  }

  Widget _nudgeCard(SmartNudge nudge) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: nudge.color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: nudge.color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: nudge.color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(nudge.icon, color: nudge.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nudge.title,
                  style: TextStyle(color: nudge.color, fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            nudge.body,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                if (nudge.route != null) context.push(nudge.route!);
              },
              style: TextButton.styleFrom(
                backgroundColor: nudge.color.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                nudge.actionLabel ?? 'View Details',
                style: TextStyle(color: nudge.color, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusSection() {
    final dna = _data?['dna'] ?? {};
    final streak = dna['study_streak'] ?? 0;
    final focusTime = dna['focus_score'] != null ? '${(dna['focus_score'] as num).toInt()}m' : '0m';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Today's Focus", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _focusStat('Study Streak', '$streak days 🔥', Icons.local_fire_department, Colors.orange)),
            const SizedBox(width: 16),
            Expanded(child: _focusStat('Focus Score', focusTime, Icons.timer_outlined, Colors.blue)),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: () => NativeNavigationService.openFocusMode(),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6200EE),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Start PomoAI (Native)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _focusStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          children: [
            _actionIcon('Opportunities', Icons.explore_outlined, Colors.purple, '/opportunities'),
            _actionIcon('Teams', Icons.groups_outlined, Colors.indigo, '/team_finder'),
            _actionIcon('CampusOS', Icons.hub_outlined, Colors.teal, '/campus_connect'),
            _actionIcon('Skills', Icons.verified_outlined, Colors.blue, '/skill_reality'),
            _actionIcon('ScamShield', Icons.shield_outlined, Colors.red, '/scam_shield'),
            _actionIcon('Sustainability', Icons.eco_outlined, Colors.green, '/sustainability'),
          ],
        ),
      ],
    );
  }

  Widget _actionIcon(String label, IconData icon, Color color, String route) {
    return InkWell(
      onTap: () => context.push(route),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildUpcomingSection() {
    final featured = _data?['featured_opportunities'] as List? ?? [];
    final notifications = _data?['unread_notifications'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Upcoming', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(onPressed: () {}, child: const Text('See all')),
          ],
        ),
        if (featured.isEmpty && notifications.isEmpty) ...[
          _upcomingItem('Build Your DNA', 'Complete quiz to unlock features', 'Nudge', Colors.orange),
          _upcomingItem('Setup Profile', 'Verify your college record', 'Nudge', Colors.teal),
        ] else ...[
          ...featured.map((o) => _upcomingItem(
            o['title'],
            'Deadline: ${o['apply_deadline'].toString().split('T')[0]}',
            o['type'].toString().toUpperCase(),
            Colors.purple
          )),
          ...notifications.map((n) => _upcomingItem(
            n['title'],
            n['body'] ?? '',
            'Alert',
            Colors.red
          )),
        ],
      ],
    );
  }

  Widget _upcomingItem(String title, String subtitle, String category, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(category, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }
}
