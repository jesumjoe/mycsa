import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import 'requirement_responses_screen.dart';

class AdminInboxScreen extends StatefulWidget {
  final String adminRole;
  final String? adminCampusId;

  const AdminInboxScreen({
    super.key,
    required this.adminRole,
    this.adminCampusId,
  });

  @override
  State<AdminInboxScreen> createState() => _AdminInboxScreenState();
}

class _AdminInboxScreenState extends State<AdminInboxScreen> {
  
  Stream<List<Map<String, dynamic>>> _getRequirementsStream() {
    var query = supabase
        .from('announcements')
        .stream(primaryKey: ['id'])
        .eq('type', 'Requirement')
        .order('created_at', ascending: false);
    
    // Note: Stream filtering is limited. We might filter more in the builder if needed.
    // For now, we fetch all requirements and filter visually if needed.
    return query;
  }

  Future<int> _getResponseCount(String announcementId) async {
    final res = await supabase
        .from('requirement_responses')
        .select()
        .eq('announcement_id', announcementId);
    return (res as List).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text("Inbox / Requirements"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getRequirementsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final requirements = snapshot.data!;
          
          if (requirements.isEmpty) {
             return Center(child: Text("No requirements posted yet", style: TextStyle(color: Colors.white.withOpacity(0.5))));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requirements.length,
            itemBuilder: (context, index) {
              final req = requirements[index];
              
              // Filter logic: Only show my campus requirements if I am not Global
              if (widget.adminRole != 'OverallHead') {
                 if (req['is_global'] == false && req['target_campus'] != widget.adminCampusId) {
                   return const SizedBox.shrink(); 
                 }
              }

              return _buildInboxCard(req, index);
            },
          );
        },
      ),
    );
  }

  Widget _buildInboxCard(Map<String, dynamic> req, int index) {
    final title = req['title'] ?? 'Untitled';
    final created = DateTime.parse(req['created_at']).toLocal();
    final timeStr = DateFormat('MMM d, h:mm a').format(created);
    final deadlineStr = req['deadline'];
    bool isExpired = false;
    if (deadlineStr != null) {
      isExpired = DateTime.parse(deadlineStr).isBefore(DateTime.now());
    }

    return FutureBuilder<int>(
      future: _getResponseCount(req['id']),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return Card(
          color: AppTheme.primaryNavy,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text("Posted: $timeStr", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                if (isExpired)
                  Text("Expired", style: TextStyle(color: Colors.redAccent.withOpacity(0.7), fontSize: 12)),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: count > 0 ? AppTheme.accentBlue : Colors.white10,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "$count Responses",
                style: TextStyle(
                  color: count > 0 ? Colors.black : Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 12
                ),
              ),
            ),
            onTap: () {
               Navigator.push(
                 context, 
                 MaterialPageRoute(builder: (context) => RequirementResponsesScreen(announcementId: req['id'], title: title))
               );
            },

          ),
        );
      }
    );
  }
}
