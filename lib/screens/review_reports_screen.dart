import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class ReviewReportsScreen extends StatefulWidget {
  final String campusId;
  const ReviewReportsScreen({super.key, required this.campusId});

  @override
  State<ReviewReportsScreen> createState() => _ReviewReportsScreenState();
}

class _ReviewReportsScreenState extends State<ReviewReportsScreen> {
  late Stream<List<Map<String, dynamic>>> _reportsStream;

  @override
  void initState() {
    super.initState();
    _reportsStream = supabase
        .from('reports')
        .stream(primaryKey: ['id'])
        .eq('campus_id', widget.campusId)
        .order('created_at', ascending: false)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  Future<void> _markAsReviewed(String reportId) async {
    try {
      await supabase
          .from('reports')
          .update({'status': 'Reviewed'}).eq('id', reportId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report marked as reviewed')),
        );
        Navigator.pop(context); // Close detail dialog
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showReportDetails(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primaryNavy,
        title:
            Text(report['title'], style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Status: ${report['status']}",
                style: TextStyle(
                    color: report['status'] == 'Reviewed'
                        ? Colors.greenAccent
                        : Colors.orangeAccent)),
            const SizedBox(height: 10),
            const Text("Description:",
                style: TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.bold)),
            Text(report['description'] ?? "No description",
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            if (report['link'] != null && report['link'].toString().isNotEmpty)
              InkWell(
                onTap: () async {
                  final uri = Uri.tryParse(report['link']);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                child: Text(
                  "Attached Link: ${report['link']}",
                  style: const TextStyle(
                      color: Colors.blueAccent,
                      decoration: TextDecoration.underline),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          if (report['status'] != 'Reviewed')
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue),
              onPressed: () => _markAsReviewed(report['id']),
              child: const Text("Mark as Reviewed"),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text("Submitted Reports"),
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _reportsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text("Error: ${snapshot.error}",
                    style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reports = snapshot.data!;
          if (reports.isEmpty) {
            return const Center(
              child: Text("No reports submitted yet.",
                  style: TextStyle(color: Colors.white54)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              final isReviewed = report['status'] == 'Reviewed';

              return Card(
                color: AppTheme.primaryNavy,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(
                    isReviewed ? Icons.check_circle : Icons.pending,
                    color:
                        isReviewed ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                  title: Text(report['title'],
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    "Submitted: ${DateTime.parse(report['created_at']).toString().split(' ')[0]}",
                    style: const TextStyle(color: Colors.white54),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      color: Colors.white24, size: 16),
                  onTap: () => _showReportDetails(report),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
