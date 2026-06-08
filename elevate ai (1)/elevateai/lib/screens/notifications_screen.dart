import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../flutter_integration.dart';
import '../widgets/loading_skeleton.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _notificationService = NotificationService();
  bool _isLoading = true;
  bool _isGeneratingDigest = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToRealtime();
  }

  void _subscribeToRealtime() {
    final user = supabase.auth.currentUser;
    if (user != null) {
      _notificationService.subscribeToNotifications(
        studentId: user.id,
        onNewNotification: (notif) {
          if (mounted) {
            setState(() {
              _notifications.insert(0, notif);
            });
          }
        },
      );
    }
  }

  Future<void> _loadData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final data = await _notificationService.getNotifications(studentId: user.id);
        if (mounted) {
          setState(() {
            _notifications = data;
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

  Future<void> _generateDigest() async {
    setState(() => _isGeneratingDigest = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final res = await supabase.functions.invoke('generate-smart-digest', body: {
        'student_id': user.id,
      });

      if (res.status == 200) {
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Smart Digest generated!')),
          );
        }
      } else {
        throw Exception(res.data['error'] ?? 'Digest failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingDigest = false);
    }
  }

  Future<void> _markAllRead() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      await _notificationService.markAllAsRead(user.id);
      _loadData();
    }
  }

  Future<void> _markRead(String id) async {
    await _notificationService.markAsRead(id);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _buildNotificationList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isGeneratingDigest ? null : _generateDigest,
        label: Text(_isGeneratingDigest ? 'Generating...' : 'Smart Digest'),
        icon: _isGeneratingDigest
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.auto_awesome),
        backgroundColor: Colors.indigo,
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: LoadingSkeleton(height: 80, width: double.infinity),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_errorMessage!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notifications_none, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('You\'re all caught up', style: TextStyle(color: Colors.grey, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildNotificationList() {
    if (_notifications.isEmpty) return _buildEmptyState();

    final unread = _notifications.where((n) => !n['is_read']).toList();
    final read = _notifications.where((n) => n['is_read']).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (unread.any((n) => n['type'] == 'smart_digest')) ...[
             _buildDigestBanner(unread.firstWhere((n) => n['type'] == 'smart_digest')),
             const SizedBox(height: 16),
          ],
          if (unread.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Unread', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            ...unread.map(_buildNotificationTile),
          ],
          if (read.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Earlier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            ...read.map(_buildNotificationTile),
          ],
          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildDigestBanner(Map<String, dynamic> digest) {
    final data = digest['data'] ?? {};
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.indigo, Colors.blue]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('✨ SMART DIGEST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                onPressed: () => _markRead(digest['id']),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(digest['body'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (data['low_summary'] != null)
            Text('• ${data['low_summary']}', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => _showDigestDetails(digest),
            style: TextButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), foregroundColor: Colors.white),
            child: const Text('View Breakdown'),
          ),
        ],
      ),
    );
  }

  void _showDigestDetails(Map<String, dynamic> digest) {
    final data = digest['data'] ?? {};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(32.0),
          child: ListView(
            controller: scrollController,
            children: [
              const Text('Daily Intelligence', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(DateFormat.yMMMMd().format(DateTime.parse(digest['created_at'])), style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              if (data['critical_items'] != null && (data['critical_items'] as List).isNotEmpty) ...[
                const Text('URGENT ITEMS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 12),
                ...(data['critical_items'] as List).map((i) => _digestItem(i, Colors.red)),
                const SizedBox(height: 24),
              ],
              if (data['important_items'] != null && (data['important_items'] as List).isNotEmpty) ...[
                const Text('IMPORTANT UPDATES', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                const SizedBox(height: 12),
                ...(data['important_items'] as List).map((i) => _digestItem(i, Colors.indigo)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _digestItem(Map<String, dynamic> i, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(i['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(i['body'] ?? '', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(Map<String, dynamic> n) {
    if (n['type'] == 'smart_digest') return const SizedBox.shrink(); // Handled as banner

    return Dismissible(
      key: Key(n['id']),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _markRead(n['id']),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: _getIcon(n['type']),
          title: Text(n['title'], style: TextStyle(fontWeight: n['is_read'] ? FontWeight.normal : FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n['body'] ?? ''),
              const SizedBox(height: 4),
              Text(
                DateFormat.jm().format(DateTime.parse(n['created_at'])),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          onTap: () {
            if (!n['is_read']) _markRead(n['id']);
          },
        ),
      ),
    );
  }

  Widget _getIcon(String? type) {
    switch (type) {
      case 'badge_earned': return const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.verified, color: Colors.white));
      case 'challenge_result': return const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.assessment, color: Colors.white));
      case 'debrief_request': return const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.rate_review, color: Colors.white));
      case 'scam_alert': return const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.warning, color: Colors.white));
      case 'dna_quiz_complete': return const CircleAvatar(backgroundColor: Colors.purple, child: Icon(Icons.fingerprint, color: Colors.white));
      default: return const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.notifications, color: Colors.white));
    }
  }
}
