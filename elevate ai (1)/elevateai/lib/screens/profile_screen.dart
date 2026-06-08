import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../flutter_integration.dart';
import '../services/erp_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final data = await supabase
            .from('student_profiles')
            .select('*, colleges(name, short_name)')
            .eq('id', user.id)
            .single();
        if (mounted) {
          setState(() {
            _profileData = data;
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

  void _syncERP() async {
    final user = supabase.auth.currentUser;
    final collegeId = _profileData?['college_id'];
    if (user == null || collegeId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ERPProgressDialog(),
    );

    // Actual sync logic
    try {
      await ERPService().syncCollegeRecords(user.id, collegeId);

      if (mounted) {
        Navigator.pop(context); // Close dialog
        _loadProfile(); // Refresh
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ERP Records Synced Successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final user = supabase.auth.currentUser;
    final isGuest = user == null;
    final name = _profileData?['full_name'] ?? (isGuest ? 'Test Student' : 'Student');
    final college = _profileData?['colleges']?['short_name'] ?? 'N/A';
    final avatar = _profileData?['avatar_url'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          if (!isGuest) IconButton(onPressed: _syncERP, icon: const Icon(Icons.sync, color: Color(0xFF6200EE))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildProfileHeader(name, college, avatar),
            const SizedBox(height: 32),
            if (isGuest) _buildSignUpBanner(),
            const SizedBox(height: 24),
            _buildDirectoryItem(Icons.person_outline, 'Personal Information', () {}),
            _buildDirectoryItem(Icons.school, 'Academic Records', () {},
              subtitle: 'Synced from ERP: ${_profileData?['roll_number'] ?? 'N/A'}'
            ),
            _buildDirectoryItem(Icons.account_balance_wallet_outlined, 'Scholarships & Aids', () {}),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(),
            ),

            _buildDirectoryItem(Icons.folder_shared_outlined, 'Digital Portfolio', () => context.push('/portfolio')),
            _buildDirectoryItem(Icons.emoji_events_outlined, 'Achievements', () => context.push('/achievements')),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(),
            ),
            _buildDirectoryItem(Icons.settings_outlined, 'Settings', () {}),
            _buildDirectoryItem(Icons.help_outline, 'Help & Support', () {}),
            const SizedBox(height: 40),
            _buildLogoutButton(isGuest),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF6200EE).withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF6200EE).withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Text('Currently in Test Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Create an account to save your progress and access all features.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.go('/welcome'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6200EE)),
              child: const Text('Sign Up Now'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(String name, String college, String? avatar) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey.shade100,
          backgroundImage: avatar != null ? NetworkImage(avatar) : null,
          child: avatar == null ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
        ),
        const SizedBox(height: 16),
        Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(college, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildDirectoryItem(IconData icon, String label, VoidCallback onTap, {String? subtitle, Widget? trailing}) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.grey.shade700, size: 22),
      ),
      title: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
    );
  }

  Widget _buildLogoutButton(bool isGuest) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: () async {
          if (!isGuest) {
            await supabase.auth.signOut();
          }
          if (mounted) context.go('/welcome');
        },
        icon: Icon(isGuest ? Icons.arrow_back : Icons.logout, color: Colors.red),
        label: Text(isGuest ? 'Exit Test Mode' : 'Logout', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

class ERPProgressDialog extends StatefulWidget {
  const ERPProgressDialog({super.key});

  @override
  State<ERPProgressDialog> createState() => _ERPProgressDialogState();
}

class _ERPProgressDialogState extends State<ERPProgressDialog> {
  int _step = 0;
  final List<String> _steps = [
    'Connecting to ERP...',
    'Importing Attendance...',
    'Importing Assignment Scores...',
    'Fetching Academic Records...',
    'Syncing Project Participation...',
    'Updating TrustScore & DNA...',
  ];

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  void _startAnimation() async {
    for (int i = 0; i < _steps.length; i++) {
      if (!mounted) return;
      setState(() => _step = i);
      await Future.delayed(const Duration(milliseconds: 1200));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF6200EE)),
            const SizedBox(height: 24),
            const Text(
              'Syncing College Records',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _steps[_step],
                  key: ValueKey(_step),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (_step + 1) / _steps.length,
                backgroundColor: Colors.grey.shade100,
                color: const Color(0xFF6200EE),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
