import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'login_screen.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'announcement_detail_screen.dart';
import 'chat/chat_list_screen.dart';

class VolunteerHomeScreen extends StatefulWidget {
  const VolunteerHomeScreen({super.key});

  @override
  State<VolunteerHomeScreen> createState() => _VolunteerHomeScreenState();
}

class _VolunteerHomeScreenState extends State<VolunteerHomeScreen> with SingleTickerProviderStateMixin {
  late final Future<Map<String, dynamic>> _profileFuture;
  late TabController _tabController;
  
  // Cache user details for filtering
  String? _userCampus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _profileFuture = _fetchUserProfile();
  }

  Future<Map<String, dynamic>> _fetchUserProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not logged in.');
    
    final response = await supabase
        .from('users')
        .select('registerNumber, name, campusId')
        .eq('id', user.id)
        .single();
    
    _userCampus = response['campusId']; // Store for filtering
    return response as Map<String, dynamic>;
  }

  Future<void> _logout(BuildContext context) async {
    await supabase.auth.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('CSA Volunteer'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.send_rounded), 
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatListScreen()));
            }
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout(context)),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentBlue,
          labelColor: AppTheme.accentBlue,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "News Feed", icon: Icon(Icons.newspaper_rounded)),
            Tab(text: "My Activity", icon: Icon(Icons.history_rounded)),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

          final profile = snapshot.data!;
          
          return TabBarView(
            controller: _tabController,
            children: [
              _buildNewsFeed(profile),
              _buildActivityTab(profile),
            ],
          );
        },
      ),
    );
  }

  // --- TAB 1: NEWS FEED ---
  Widget _buildNewsFeed(Map<String, dynamic> profile) {
    // Fetch announcements that are EITHER global OR target my campus
    final stream = supabase
        .from('announcements')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        // Client-side filtering: OR conditions + Deadline check
        final now = DateTime.now();
        final allPosts = snapshot.data!;
        final myPosts = allPosts.where((post) {
           final isGlobal = post['is_global'] == true;
           final target = post['target_campus'];
           
           // Deadline Check (Disappearing Logic)
           final deadlineStr = post['deadline'] as String?;
           if (deadlineStr != null) {
             final deadline = DateTime.parse(deadlineStr).toLocal();
             if (deadline.isBefore(now)) return false; // Expired
           }

           return isGlobal || target == _userCampus;
        }).toList();

        if (myPosts.isEmpty) {
           return Center(
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 const Icon(Icons.notifications_off_outlined, size: 60, color: Colors.white24),
                 const SizedBox(height: 10),
                 Text("No updates yet", style: TextStyle(color: Colors.white.withOpacity(0.5))),
               ],
             ),
           );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: myPosts.length,
          itemBuilder: (context, index) {
            final post = myPosts[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AnnouncementDetailScreen(announcement: post)),
                );
              },
              child: _buildPostCard(post, index),
            );
          },
        );
      },
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, int index) {
    final title = post['title'] ?? 'Untitled';
    final desc = post['description'] ?? '';
    final type = post['type'] ?? 'Event';
    final isEvent = type == 'Event';
    final imageUrl = post['image_url'];
    final time = DateFormat('MMM d').format(DateTime.parse(post['created_at']).toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppTheme.primaryNavy,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
        border: isEvent ? null : Border.all(color: Colors.orangeAccent.withOpacity(0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Type Badge + Time)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isEvent ? AppTheme.accentBlue.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    type.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10, 
                      fontWeight: FontWeight.bold,
                      color: isEvent ? AppTheme.accentBlue : Colors.orangeAccent,
                    ),
                  ),
                ),
                Text(time, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
              ],
            ),
          ),
          
          // Image (If Event)
          if (isEvent && imageUrl != null)
             Container(
               height: 200,
               width: double.infinity,
               margin: const EdgeInsets.symmetric(vertical: 8),
               decoration: BoxDecoration(
                 image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
               ),
             ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.7), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1);
  }

  // --- TAB 2: MY ACTIVITY (Existing Logic) ---
  Widget _buildActivityTab(Map<String, dynamic> profile) {
     final registerNumber = profile['registerNumber'] ?? '';
     final logStream = supabase
              .from('attendance_logs')
              .stream(primaryKey: ['id'])
              .eq('registerNumber', registerNumber)
              .order('timestamp', ascending: true);

     return StreamBuilder<List<Map<String, dynamic>>>(
        stream: logStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final logs = snapshot.data!;
          final totalTime = _calculateTotalDuration(logs);
          final recentLogs = logs.reversed.toList();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Summary Card
                Container(
                  padding: const EdgeInsets.all(24),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppTheme.primaryNavy, AppTheme.accentBlue.withOpacity(0.2)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Text("Total Contribution", style: TextStyle(color: Colors.white54)),
                      const SizedBox(height: 8),
                      Text(totalTime, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Align(alignment: Alignment.centerLeft, child: Text("Recent Punches", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: recentLogs.length,
                    itemBuilder: (context, index) {
                      final log = recentLogs[index];
                      final isPunchIn = (log['scanType'] ?? '').toLowerCase() == 'in';
                      final time = DateFormat('MMM d, h:mm a').format(DateTime.parse(log['timestamp']).toLocal());
                      
                      return ListTile(
                        leading: Icon(isPunchIn ? Icons.login : Icons.logout, color: isPunchIn ? Colors.green : Colors.red),
                        title: Text(isPunchIn ? "Punch In" : "Punch Out", style: const TextStyle(color: Colors.white)),
                        subtitle: Text(time, style: TextStyle(color: Colors.white.withOpacity(0.5))),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
     );
  }

  String _calculateTotalDuration(List<Map<String, dynamic>> logs) {
    Duration total = Duration.zero;
    DateTime? inTime;
    for (var log in logs) {
      final t = DateTime.parse(log['timestamp']).toLocal();
      if (log['scanType'] == 'in') {
        inTime = t;
      } else if (log['scanType'] == 'out' && inTime != null) {
        total += t.difference(inTime);
        inTime = null;
      }
    }
    return "${total.inHours}h ${total.inMinutes % 60}m";
  }
}
