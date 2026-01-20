import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../main.dart'; // supabase client

class AnnouncementDetailScreen extends StatefulWidget {
  final Map<String, dynamic> announcement;

  const AnnouncementDetailScreen({super.key, required this.announcement});

  @override
  State<AnnouncementDetailScreen> createState() => _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  final TextEditingController _msgController = TextEditingController();
  bool _isResponding = false;
  bool _hasResponded = false;

  @override
  void initState() {
    super.initState();
    _checkIfResponded();
  }

  Future<void> _checkIfResponded() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final id = widget.announcement['id'];
    final res = await supabase
        .from('requirement_responses')
        .select()
        .eq('announcement_id', id)
        .eq('user_id', user.id)
        .maybeSingle();

    if (res != null && mounted) {
      setState(() => _hasResponded = true);
    }
  }

  Future<void> _sendResponse() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    
    setState(() => _isResponding = true);

    try {
       await supabase.from('requirement_responses').insert({
         'announcement_id': widget.announcement['id'],
         'user_id': user.id,
         'status': 'Available',
         'message': _msgController.text.trim(),
       });

       setState(() => _hasResponded = true);
       if(mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Response Sent!")));
       }
    } catch(e) {
      debugPrint("Error responding: $e");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send response.")));
      }
    } finally {
      if(mounted) setState(() => _isResponding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.announcement;
    final String title = data['title'] ?? 'No Title';
    final String desc = data['description'] ?? 'No Description';
    final String? imageUrl = data['image_url'];
    final bool isEvent = data['type'] == 'Event';
    final String? deadlineStr = data['deadline'];

    DateTime? deadline;
    if (deadlineStr != null) deadline = DateTime.parse(deadlineStr).toLocal();

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: CustomScrollView(
        slivers: [
          // 1. Hero Image App Bar
          SliverAppBar(
             expandedHeight: isEvent && imageUrl != null ? 300 : 120,
             backgroundColor: AppTheme.primaryNavy,
             pinned: true,
             flexibleSpace: FlexibleSpaceBar(
               title: Text(title, 
                  style: const TextStyle(
                    color: Colors.white, 
                    fontWeight: FontWeight.bold, 
                    shadows: [Shadow(color: Colors.black, blurRadius: 10)]
                  ),
               ),
               background: isEvent && imageUrl != null 
                  ? Image.network(imageUrl, fit: BoxFit.cover)
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryNavy, AppTheme.accentBlue.withOpacity(0.3)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter
                        )
                      ),
                      child: Center(child: Icon(isEvent ? Icons.event : Icons.task_alt, size: 60, color: Colors.white10)),
                    ),
             ),
          ),

          // 2. Content Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Deadline Badge
                  if (deadline != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, color: Colors.redAccent, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            "Expires: ${DateFormat('MMM d, h:mm a').format(deadline)}",
                            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Description
                  Text(
                    "Details",
                    style: TextStyle(color: AppTheme.lightBlue.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    desc,
                    style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                  ),
                  
                  const SizedBox(height: 40),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 20),

                  // 3. Interaction Section (For Requirements)
                  if (!isEvent) ...[
                    Text(
                      _hasResponded ? "Your Response" : "Are you available?",
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    if (_hasResponded)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 12),
                            Text("You have marked yourself available.", style: TextStyle(color: Colors.greenAccent)),
                          ],
                        ),
                      )
                    else 
                      Column(
                        children: [
                          TextField(
                            controller: _msgController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Add a note (e.g. 'Available after 5pm')",
                              hintStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: AppTheme.primaryNavy,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _isResponding ? null : _sendResponse,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentBlue,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: _isResponding 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) 
                                  : const Icon(Icons.send_rounded, color: Colors.black),
                              label: Text(_isResponding ? "Sending..." : "I'm Available", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                  ] else ...[
                     // Event Footer
                     Center(
                       child: Text(
                         "Events are open to all. Check details above.",
                         style: TextStyle(color: Colors.white.withOpacity(0.3)),
                       ),
                     )
                  ]
                ],
              ),
            ),
          )
        ],
      ).animate().fadeIn(),
    );
  }
}
