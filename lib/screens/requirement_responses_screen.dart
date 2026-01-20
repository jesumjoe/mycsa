import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/chat_service.dart';
import 'chat/chat_screen.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class RequirementResponsesScreen extends StatefulWidget {
  final String announcementId;
  final String title;

  const RequirementResponsesScreen({super.key, required this.announcementId, required this.title});

  @override
  State<RequirementResponsesScreen> createState() => _RequirementResponsesScreenState();
}

class _RequirementResponsesScreenState extends State<RequirementResponsesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _responses = [];

  @override
  void initState() {
    super.initState();
    _fetchResponses();
  }

  Future<void> _fetchResponses() async {
    try {
      // 1. Fetch Responses
      final responseData = await supabase
          .from('requirement_responses')
          .select('*, users(name, registerNumber, role, campusId)') // Join with users
          .eq('announcement_id', widget.announcementId)
          .order('created_at', ascending: false);
      
      setState(() {
        _responses = List<Map<String, dynamic>>.from(responseData);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching responses: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _responses.isEmpty
            ? Center(child: Text("No responses yet.", style: TextStyle(color: Colors.white.withOpacity(0.5))))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _responses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildResponseCard(_responses[index]);
                },
              ),
    );
  }

  Widget _buildResponseCard(Map<String, dynamic> data) {
    final user = data['users'] as Map<String, dynamic>? ?? {};
    final name = user['name'] ?? 'Unknown User';
    final regNo = user['registerNumber'] ?? '';
    final role = user['role'] ?? 'Volunteer';
    final message = data['message'] ?? '';
    final timestamp = DateTime.parse(data['created_at']).toLocal();
    final timeStr = DateFormat('MMM d, h:mm a').format(timestamp);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryNavy,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(timeStr, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
            ],
          ),
          Text("$role | $regNo", style: TextStyle(color: AppTheme.accentBlue.withOpacity(0.7), fontSize: 12)),
          
          if (message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message,
                style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
              ),
            ),
          ],

          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _openChat(data['user_id'], name, role),
              icon: const Icon(Icons.chat_bubble_outline, size: 18, color: AppTheme.accentBlue),
              label: const Text("Message", style: TextStyle(color: AppTheme.accentBlue)),
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.accentBlue.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          )
        ],
      ),
    );
  }

  void _openChat(String userId, String name, String role) async {
    final chatService = ChatService();
    try {
      final convoId = await chatService.createOrGetConversation(userId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatScreen(
          conversationId: convoId,
          otherUserName: name,
          otherUserRole: role,
        )),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}
