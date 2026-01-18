import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart'; // for supabase client
import '../theme/app_theme.dart';

class AttendanceLogsScreen extends StatefulWidget {
  final String role;
  final String? campusId;

  const AttendanceLogsScreen({
    super.key,
    required this.role,
    this.campusId,
  });

  @override
  State<AttendanceLogsScreen> createState() => _AttendanceLogsScreenState();
}

class _AttendanceLogsScreenState extends State<AttendanceLogsScreen> {
  DateTime? _selectedDate;
  String? _selectedCampusFilter;

  final List<String> _campusOptions = [
    'All',
    'BKC',
    'CampusB',
    'CampusC',
    'CampusD'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.role == 'CampusHead') {
      _selectedCampusFilter = widget.campusId;
    } else {
      _selectedCampusFilter = 'All';
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accentBlue,
              onPrimary: AppTheme.white,
              surface: AppTheme.primaryNavy,
              onSurface: AppTheme.white,
            ),
            dialogBackgroundColor: AppTheme.primaryNavy,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchLogs() async {
    debugPrint("Fetching logs...");
    var query = supabase.from('attendance_logs').select('*'); 

    if (_selectedCampusFilter != null && _selectedCampusFilter != 'All') {
      query = query.eq('campusId', _selectedCampusFilter!);
    }

    if (_selectedDate != null) {
      final startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      query = query
        .gte('timestamp', startOfDay.toIso8601String())
        .lt('timestamp', endOfDay.toIso8601String());
    }

    final response = await query.order('timestamp', ascending: false);
    final logs = List<Map<String, dynamic>>.from(response);

    if (logs.isEmpty) return [];

    // 1. Collect all unique UIDs (both Attendees and Admins)
    final attendeeRegs = logs.map((log) => log['registerNumber'] as String).toSet().toList();
    final adminUids = logs.map((log) => log['scannedByUID'] as String?).where((uid) => uid != null).toSet().toList();

    // 2. Fetch Attendees (by Register Number)
    final attendeeResponse = await supabase
        .from('users')
        .select('registerNumber, name')
        .filter('registerNumber', 'in', attendeeRegs);
    
    // 3. Fetch Admins (by UUID)
    List<Map<String, dynamic>> adminResponse = [];
    if (adminUids.isNotEmpty) {
      final res = await supabase
          .from('users')
          .select('id, name, role')
          .filter('id', 'in', adminUids);
      adminResponse = List<Map<String, dynamic>>.from(res);
    }
    
    // 4. Create Maps
    final attendeeMap = {
      for (var user in List<Map<String, dynamic>>.from(attendeeResponse)) 
        user['registerNumber'] as String: user['name'] as String
    };

    final adminMap = {
      for (var admin in adminResponse) 
        admin['id'] as String: {'name': admin['name'], 'role': admin['role']}
    };

    // 5. Enrich Logs
    for (var log in logs) {
      final regNo = log['registerNumber'] as String;
      final adminId = log['scannedByUID'] as String?;
      
      log['userName'] = attendeeMap[regNo] ?? 'Unknown User';
      
      if (adminId != null && adminMap.containsKey(adminId)) {
        log['adminName'] = adminMap[adminId]!['name'];
        log['adminRole'] = adminMap[adminId]!['role'];
      } else {
        log['adminName'] = 'Unknown Admin';
      }
    }

    return logs;
  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null) return 'Invalid date';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      return DateFormat('MMM d, h:mm a').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Attendance Logs'),
        actions: [
          IconButton(
             icon: const Icon(Icons.refresh),
             onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters Section
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppTheme.primaryNavy,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
              ],
            ),
            child: Row(
              children: [
                if (widget.role == 'OverallHead') 
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCampusFilter,
                      dropdownColor: AppTheme.primaryNavy,
                      decoration: const InputDecoration(
                        labelText: 'Campus',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      ),
                      style: const TextStyle(color: AppTheme.white),
                      items: _campusOptions.map((String campus) {
                        return DropdownMenuItem<String>(
                          value: campus,
                          child: Text(campus),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() => _selectedCampusFilter = newValue);
                      },
                    ),
                  ),
                if (widget.role == 'OverallHead') const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _selectedDate == null ? 'Date' : DateFormat('MMM d').format(_selectedDate!),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (_selectedDate != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => setState(() => _selectedDate = null),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 10),

          // Logs List
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchLogs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }
                
                final logs = snapshot.data;
                if (logs == null || logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.history_toggle_off, size: 60, color: Colors.white24),
                        const SizedBox(height: 10),
                        Text('No records found', style: TextStyle(color: AppTheme.lightBlue.withOpacity(0.5))),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final registerNumber = log['registerNumber'] as String? ?? 'N/A';
                    final scanType = (log['scanType'] as String? ?? 'N/A').toUpperCase();
                    final timestamp = log['timestamp'] as String?;
                    final userName = log['userName'] as String? ?? 'Unknown User';
                    final adminName = log['adminName'] as String?;
                    
                    final isPunchIn = scanType == 'IN';
                    // Use theme colors for chips
                    final chipColor = isPunchIn ? Colors.tealAccent.withOpacity(0.1) : Colors.orangeAccent.withOpacity(0.1);
                    final chipTextColor = isPunchIn ? Colors.tealAccent : Colors.orangeAccent;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: AppTheme.primaryNavy, // Dark Card
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon Avatar
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: chipColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isPunchIn ? Icons.login : Icons.logout,
                                    color: chipTextColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.white)),
                                      const SizedBox(height: 4),
                                      Text(registerNumber, style: TextStyle(color: AppTheme.lightBlue.withOpacity(0.7), fontSize: 12)),
                                    ],
                                  ),
                                ),
                                // Access & Time
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: chipColor,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: chipTextColor.withOpacity(0.3), width: 1),
                                      ),
                                      child: Text(scanType, style: TextStyle(color: chipTextColor, fontWeight: FontWeight.bold, fontSize: 10)),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(_formatTimestamp(timestamp), style: TextStyle(color: AppTheme.white.withOpacity(0.6), fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                            
                            // Authorization Footer
                            if (adminName != null) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Divider(height: 1, color: AppTheme.white.withOpacity(0.1)),
                              ),
                              Row(
                                children: [
                                  Icon(Icons.verified_user_outlined, size: 14, color: AppTheme.accentBlue.withOpacity(0.7)),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Authorized by: ", 
                                    style: TextStyle(color: AppTheme.white.withOpacity(0.5), fontSize: 11)
                                  ),
                                  Text(
                                    adminName, 
                                    style: const TextStyle(color: AppTheme.accentBlue, fontSize: 11, fontWeight: FontWeight.w600)
                                  ),
                                ],
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
