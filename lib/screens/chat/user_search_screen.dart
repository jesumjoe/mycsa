import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/chat_service.dart';
import 'chat_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ChatService _chatService = ChatService();
  
  bool _isLoading = false;
  Map<String, dynamic>? _foundUser;
  String _errorMessage = '';

  Future<void> _performSearch() async {
    final regNo = _searchController.text.trim();
    if (regNo.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _foundUser = null;
    });

    try {
      final user = await _chatService.searchUserByRegisterNumber(regNo);
      setState(() {
        _foundUser = user;
        if (user == null) {
          _errorMessage = "No user found with Register Number: $regNo";
        }
      });
    } catch (e) {
      setState(() => _errorMessage = "Error searching: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startChat() async {
    if (_foundUser == null) return;
    
    setState(() => _isLoading = true);
    try {
      final convoId = await _chatService.createOrGetConversation(_foundUser!['id']);
      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ChatScreen(
          conversationId: convoId,
          otherUserName: _foundUser!['name'],
          otherUserRole: _foundUser!['role'],
        )),
      );
    } catch (e) {
       setState(() {
         _isLoading = false;
         _errorMessage = "Failed to start chat: $e";
       });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("New Message", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Enter Register Number (e.g., 2211234)",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: AppTheme.primaryNavy,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: AppTheme.accentBlue),
                  onPressed: _performSearch,
                ),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
            const SizedBox(height: 24),

            // Content
            if (_isLoading)
               const Center(child: CircularProgressIndicator(color: AppTheme.accentBlue))
            else if (_errorMessage.isNotEmpty)
               Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent)))
            else if (_foundUser != null)
               _buildUserCard(_foundUser!)
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Card(
      color: AppTheme.primaryNavy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white10,
              child: Icon(Icons.person, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              user['name'] ?? 'Unknown',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              "${user['role']} • ${user['registerNumber']}",
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startChat,
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.black),
                label: const Text("Start Conversation", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
