import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class ChatService {
  
  /// Gets the current user ID
  String? get _myId => supabase.auth.currentUser?.id;

  /// Creates a new conversation with [recepientId] or returns existing one.
  Future<String> createOrGetConversation(String recepientId) async {
    if (_myId == null) throw Exception("Not logged in");

    // 1. Check if conversation already exists
    // Fetch all conversation IDs I am part of
    final myConvos = await supabase
        .from('participants')
        .select('conversation_id')
        .eq('user_id', _myId!);
    
    final List<String> myConvoIds = (myConvos as List)
        .map((e) => e['conversation_id'] as String)
        .toList();

    if (myConvoIds.isNotEmpty) {
      // Find which of these also has the recepient
      final commonParams = await supabase
          .from('participants')
          .select('conversation_id')
          .eq('user_id', recepientId)
          .filter('conversation_id', 'in', myConvoIds)
          .maybeSingle();
      
      if (commonParams != null) {
        return commonParams['conversation_id'] as String;
      }
    }

    // 2. Create new conversation
    final newConvo = await supabase
        .from('conversations')
        .insert({'last_message': 'Started a new chat'})
        .select()
        .single();
    
    final String convoId = newConvo['id'];

    // 3. Add Participants
    await supabase.from('participants').insert([
      {'conversation_id': convoId, 'user_id': _myId},
      {'conversation_id': convoId, 'user_id': recepientId},
    ]);

    return convoId;
  }

  /// returns a Stream of messages for a specific conversation
  Stream<List<Map<String, dynamic>>> getMessagesStream(String conversationId) {
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
  }

  /// Sends a text message
  Future<void> sendMessage(String conversationId, String content) async {
    if (_myId == null) return;
    
    await supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': _myId,
      'content': content,
    });

    // Update last message preview
    await supabase.from('conversations').update({
      'last_message': content,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', conversationId);
  }

  /// Fetches conversation list with details
  Future<List<Map<String, dynamic>>> getMyConversations() async {
     if (_myId == null) return [];

     // 1. Get my conversation IDs
     final myParts = await supabase
         .from('participants')
         .select('conversation_id')
         .eq('user_id', _myId!);
     
     final List<String> ids = (myParts as List).map((e) => e['conversation_id'] as String).toList();
     if (ids.isEmpty) return [];

     // 2. Fetch Conversations details
     final convos = await supabase
         .from('conversations')
         .select()
         .filter('id', 'in', ids)
         .order('updated_at', ascending: false);
      
     List<Map<String, dynamic>> results = [];

     // 3. Enrich with "Other User" info
     for (var c in (convos as List)) {
       final convo = Map<String, dynamic>.from(c);
       final String cId = convo['id'];

       // Get the *other* participant
       final otherPart = await supabase
           .from('participants')
           .select('users(name, role)') 
           .eq('conversation_id', cId)
           .neq('user_id', _myId!)
           .maybeSingle(); 
       
       if (otherPart != null) {
          final user = otherPart['users'];
          convo['other_name'] = user['name'];
          convo['other_role'] = user['role'];
       } else {
          convo['other_name'] = 'Unknown';
          convo['other_role'] = '';
       }
       results.add(convo);
     }
     
     return results;
  }


  /// Finds a user by their exact Register Number
  Future<Map<String, dynamic>?> searchUserByRegisterNumber(String registerNumber) async {
    final res = await supabase
        .from('users')
        .select('id, name, role, registerNumber, campusId, cohort')
        .eq('registerNumber', registerNumber)
        .maybeSingle();
    return res;
  }
}
