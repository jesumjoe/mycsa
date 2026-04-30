import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class ManageDeadlinesScreen extends StatefulWidget {
  final String campusId;
  const ManageDeadlinesScreen({super.key, required this.campusId});

  @override
  State<ManageDeadlinesScreen> createState() => _ManageDeadlinesScreenState();
}

class _ManageDeadlinesScreenState extends State<ManageDeadlinesScreen> {
  final _titleController = TextEditingController();
  DateTime? _selectedDate;
  bool _loading = false;

  // Create a stream for real-time updates
  late Stream<List<Map<String, dynamic>>> _deadlinesStream;

  @override
  void initState() {
    super.initState();
    _deadlinesStream = supabase
        .from('report_deadlines')
        .stream(primaryKey: ['id'])
        .eq('campus_id', widget.campusId)
        .order('created_at', ascending: false)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  Future<void> _createDeadline() async {
    if (_titleController.text.isEmpty || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter title and date')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await supabase.from('report_deadlines').insert({
        'title': _titleController.text.trim(),
        'due_date': _selectedDate!.toIso8601String(),
        'campus_id': widget.campusId,
        'created_by': supabase.auth.currentUser!.id,
      });

      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deadline created successfully')),
        );
        _titleController.clear();
        _selectedDate = null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.primaryNavy,
          title: const Text("New Report Deadline",
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Month/Title (e.g., October Report)",
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _selectedDate == null
                      ? "Pick Due Date"
                      : "Due: ${_selectedDate.toString().split(' ')[0]}",
                  style: const TextStyle(color: AppTheme.accentBlue),
                ),
                trailing: const Icon(Icons.calendar_today,
                    color: AppTheme.accentBlue),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setDialogState(() => _selectedDate = picked);
                    // Also update parent state if needed, but dialog state is enough for display
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () {
                      // Call the create function from the parent widget context logic
                      // Pass a callback or handle logic here.
                      // Since _createDeadline uses main state variables, we need to ensure they are updated.
                      // Best is to call _createDeadline which reads existing variables.
                      _createDeadline();
                    },
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Create"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text("Report Deadlines"),
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppTheme.accentBlue,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _deadlinesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text("Error: ${snapshot.error}",
                    style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final deadlines = snapshot.data!;
          if (deadlines.isEmpty) {
            return const Center(
              child: Text("No deadlines set yet.",
                  style: TextStyle(color: Colors.white54)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: deadlines.length,
            itemBuilder: (context, index) {
              final item = deadlines[index];
              final date = DateTime.parse(item['due_date']);
              final isPast = date.isBefore(DateTime.now());

              return Card(
                color: AppTheme.primaryNavy,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(item['title'],
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    "Due: ${date.toString().split(' ')[0]} ${isPast ? '(Closed)' : ''}",
                    style: TextStyle(
                      color: isPast ? Colors.redAccent : AppTheme.lightBlue,
                    ),
                  ),
                  trailing:
                      const Icon(Icons.chevron_right, color: Colors.white24),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
