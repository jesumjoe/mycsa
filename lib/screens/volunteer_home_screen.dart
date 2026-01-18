import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'login_screen.dart';
import 'package:intl/intl.dart';

class VolunteerHomeScreen extends StatefulWidget {
  const VolunteerHomeScreen({super.key});

  @override
  State<VolunteerHomeScreen> createState() => _VolunteerHomeScreenState();
}

class _VolunteerHomeScreenState extends State<VolunteerHomeScreen> {
  late final Future<Map<String, dynamic>> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _fetchUserProfile();
  }

  Future<Map<String, dynamic>> _fetchUserProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Not logged in. Cannot fetch profile.');
    }
    
    debugPrint('Fetching profile for user: ${user.id}');
    try {
      final response = await supabase
          .from('users')
          .select('registerNumber, name')
          .eq('id', user.id)
          .single();
      
      debugPrint('Profile fetched: $response');
      return response as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      throw Exception('Failed to load user profile. Check RLS or network.');
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await supabase.auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      debugPrint("Error logging out: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: ${e.toString()}')),
        );
      }
    }
  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null) return 'Invalid date';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      return DateFormat('MMM d, yyyy - h:mm a').format(dateTime);
    } catch (e) {
      debugPrint('Error formatting date: $e');
      return 'Invalid date';
    }
  }

  String _calculateTotalDuration(List<Map<String, dynamic>> logs) {
    Duration totalDuration = Duration.zero;
    DateTime? punchInTime;

    for (final log in logs) { // Assumes logs are ascending
      final scanType = log['scanType'] as String?;
      final timestampStr = log['timestamp'] as String?;
      
      if (timestampStr == null) continue;

      try {
        final logTime = DateTime.parse(timestampStr).toLocal();

        if (scanType == 'in') {
          punchInTime ??= logTime;
        } else if (scanType == 'out') {
          if (punchInTime != null) {
            final sessionDuration = logTime.difference(punchInTime);
            totalDuration += sessionDuration;
            punchInTime = null;
          }
        }
      } catch (e) {
        debugPrint("Error parsing timestamp in duration calculation: $e");
      }
    }
    return _formatDuration(totalDuration);
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) {
      return '0 Hours 0 Mins';
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    String result = '';
    if (hours > 0) {
      result += '$hours Hour${hours == 1 ? '' : 's'} ';
    }
    if (minutes > 0 || hours == 0) {
      result += '$minutes Min${minutes == 1 ? '' : 's'}';
    }
    return result.trim();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (profileSnapshot.hasError || !profileSnapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: ${profileSnapshot.error ?? 'Could not load profile.'}'),
              ),
            );
          }

          final profileData = profileSnapshot.data!;
          final registerNumber = profileData['registerNumber'] as String?;
          final name = profileData['name'] as String? ?? 'Volunteer';

          if (registerNumber == null) {
            return const Center(child: Text('Error: Register Number not found.'));
          }
          
          final logStream = supabase
              .from('attendance_logs')
              .stream(primaryKey: ['id'])
              .eq('registerNumber', registerNumber)
              .order('timestamp', ascending: true); // Get logs oldest-to-newest

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, $name!',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      'Register No: $registerNumber',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'TOTAL TIME WORKED:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: logStream,
                      builder: (context, logSnapshot) {
                        if (logSnapshot.hasData) {
                          final logs = logSnapshot.data!;
                          final totalDurationString = _calculateTotalDuration(logs);
                          return Text(
                            totalDurationString,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
                          );
                        }
                        return const Text('Calculating...', style: TextStyle(color: Colors.grey));
                      },
                    ),
                    const SizedBox(height: 24),
                    Text( 
                      'Your Recent Activity (Newest First):',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: logStream,
                  builder: (context, logSnapshot) {
                    if (logSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (logSnapshot.hasError) {
                      debugPrint('Error fetching logs: ${logSnapshot.error}');
                      return const Center(child: Text('Error loading attendance logs.'));
                    }
                    final logs = logSnapshot.data;
                    if (logs == null || logs.isEmpty) {
                      return const Center(child: Text('No attendance logs found.'));
                    }

                    final descendingLogs = logs.reversed.toList(); // Show newest first

                    return ListView.builder(
                      itemCount: descendingLogs.length,
                      itemBuilder: (context, index) {
                        final log = descendingLogs[index];
                        final scanType = log['scanType'] as String? ?? 'N/A';
                        final timestamp = log['timestamp'] as String?;
                        final formattedTime = _formatTimestamp(timestamp);
                        
                        final isPunchIn = scanType.toLowerCase() == 'in';

                        return ListTile(
                          leading: Icon(
                            isPunchIn ? Icons.login : Icons.logout,
                            color: isPunchIn ? Colors.green : Colors.red,
                          ),
                          title: Text(
                            'Punch ${isPunchIn ? 'In' : 'Out'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(formattedTime),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
