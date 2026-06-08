import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../flutter_integration.dart';
import '../services/chat_service.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _chatService = ChatService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _conversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    try {
      final conversations = await _chatService.getConversations();
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _conversations.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final conv = _conversations[index];
                      final userId = supabase.auth.currentUser?.id;
                      final otherUser = conv['student_a_id'] == userId ? conv['student_b'] : conv['student_a'];
                      final lastMsg = conv['last_message'] ?? 'No messages yet';
                      final lastTime = DateTime.parse(conv['last_message_at']).toLocal();

                      return ListTile(
                        onTap: () => context.push('/chat/${conv['id']}?name=${otherUser['full_name']}'),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundImage: otherUser['avatar_url'] != null
                              ? NetworkImage(otherUser['avatar_url'])
                              : const NetworkImage('https://i.pravatar.cc/150?img=12'),
                        ),
                        title: Text(
                          otherUser['full_name'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Text(
                          lastMsg,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatTimestamp(lastTime),
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No conversations yet.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Connect with peers to start chatting.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    if (dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
    return '${dateTime.day}/${dateTime.month}';
  }
}
