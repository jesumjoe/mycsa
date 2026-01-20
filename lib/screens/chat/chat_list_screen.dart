import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';
import 'chat_screen.dart';
import 'user_search_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _service = ChatService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _conversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final res = await _service.getMyConversations();
      setState(() {
        _conversations = res;
        _isLoading = false;
      });
    } catch (e) {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text("Messages"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _conversations.isEmpty
            ? Center(child: Text("No messages yet", style: TextStyle(color: Colors.white.withOpacity(0.5))))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _conversations.length,
                itemBuilder: (context, index) {
                  return _buildConversationCard(_conversations[index], index);
                },
              ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accentBlue,
        child: const Icon(Icons.add_comment_rounded, color: Colors.black),
        onPressed: () {
           Navigator.push(context, MaterialPageRoute(builder: (context) => const UserSearchScreen()));
        },
      ),
    );
  }

  Widget _buildConversationCard(Map<String, dynamic> conv, int index) {
    final name = conv['other_name'] ?? 'Unknown';
    final role = conv['other_role'] ?? '';
    final lastMsg = conv['last_message'] ?? '';
    final timeStr = DateFormat('h:mm a').format(DateTime.parse(conv['updated_at']).toLocal());

    return Card(
      color: AppTheme.primaryNavy,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.white10,
          child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: AppTheme.accentBlue, fontWeight: FontWeight.bold)),
        ),
        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(role, style: TextStyle(color: AppTheme.accentBlue.withOpacity(0.7), fontSize: 10)),
            const SizedBox(height: 4),
            Text(lastMsg, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: Text(timeStr, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ChatScreen(
              conversationId: conv['id'],
              otherUserName: name,
              otherUserRole: role,
            )),
          ).then((_) => _loadConversations()); // Refresh on return
        },
      ),
    );
  }
}
