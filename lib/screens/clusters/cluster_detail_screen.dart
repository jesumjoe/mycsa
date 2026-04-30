import 'package:flutter/material.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';
import '../coming_soon_dialog.dart';
import '../create_announcement_screen.dart';

class ClusterDetailScreen extends StatefulWidget {
  final String clusterId;
  final String clusterName;

  const ClusterDetailScreen({
    super.key,
    required this.clusterId,
    required this.clusterName,
  });

  @override
  State<ClusterDetailScreen> createState() => _ClusterDetailScreenState();
}

class _ClusterDetailScreenState extends State<ClusterDetailScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('cluster_members')
          .select('role, user:user_id(name, role, registerNumber)')
          .eq('cluster_id', widget.clusterId);

      _members = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching cluster members: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(widget.clusterName),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: () => showComingSoonDialog(context),
            tooltip: "Group Chat",
          )
        ],
      ),
      body: Column(
        children: [
          // Actions
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Pass cluster info to CreateAnnouncementScreen
                      // Navigator.push(context, MaterialPageRoute(builder: (c) => CreateAnnouncementScreen(targetClusterId: widget.clusterId)));
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => CreateAnnouncementScreen(
                                  adminRole:
                                      'OverallHead', // Use generic or fetched role?
                                  // TODO: Update CreateAnnouncementScreen to accept targetClusterId
                                )),
                      );
                    },
                    icon: const Icon(Icons.campaign),
                    label: const Text("Post Announcement"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Members",
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.bold)),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final memberData = _members[index];
                      final user =
                          memberData['user'] as Map<String, dynamic>? ?? {};

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.white10,
                          child: Text((user['name'] ?? '?')[0]),
                        ),
                        title: Text(user['name'] ?? 'Unknown',
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text(user['role'] ?? 'Member',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.6))),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
