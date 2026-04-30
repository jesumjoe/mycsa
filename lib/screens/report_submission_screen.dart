import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class ReportSubmissionScreen extends StatefulWidget {
  final String campusId;
  const ReportSubmissionScreen({super.key, required this.campusId});

  @override
  State<ReportSubmissionScreen> createState() => _ReportSubmissionScreenState();
}

class _ReportSubmissionScreenState extends State<ReportSubmissionScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // File Upload State
  PlatformFile? _selectedFile;
  bool _isUploading = false;

  String? _selectedDeadlineId;
  List<Map<String, dynamic>> _deadlines = [];
  bool _loading = false;
  bool _fetchingDeadlines = true;

  @override
  void initState() {
    super.initState();
    _fetchDeadlines();
  }

  Future<void> _fetchDeadlines() async {
    try {
      final data = await supabase
          .from('report_deadlines')
          .select('id, title, due_date')
          .eq('campus_id', widget.campusId)
          .gte('due_date',
              DateTime.now().toIso8601String()) // Only future/active deadlines
          .order('due_date', ascending: true);

      if (mounted) {
        setState(() {
          _deadlines = List<Map<String, dynamic>>.from(data);
          _fetchingDeadlines = false;
          // Auto-select first if available
          if (_deadlines.isNotEmpty) {
            _selectedDeadlineId = _deadlines.first['id'];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _fetchingDeadlines = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching deadlines: $e')),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );

      if (result != null) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  Future<String?> _uploadFile() async {
    if (_selectedFile == null) return null;

    setState(() => _isUploading = true);

    try {
      final userId = supabase.auth.currentUser!.id;
      final fileExt = _selectedFile!.extension ?? 'pdf';
      final fileName =
          '${widget.campusId}/${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      // Upload file to Supabase Storage
      if (_selectedFile!.bytes != null) {
        // Web or when bytes are available
        await supabase.storage.from('report_docs').uploadBinary(
              fileName,
              _selectedFile!.bytes!,
              fileOptions: const FileOptions(upsert: true),
            );
      } else if (_selectedFile!.path != null) {
        // Mobile / Desktop with path
        final file = File(_selectedFile!.path!);
        await supabase.storage.from('report_docs').upload(
              fileName,
              file,
              fileOptions: const FileOptions(upsert: true),
            );
      }

      // Get Public URL
      final publicUrl =
          supabase.storage.from('report_docs').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      debugPrint("Upload Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading file: $e')),
      );
      return null;
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _submitReport() async {
    if (_titleController.text.isEmpty || _selectedDeadlineId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a deadline and enter a title')),
      );
      return;
    }

    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attach a document')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // 1. Upload File first
      String? fileUrl = await _uploadFile();
      if (fileUrl == null) {
        throw "File upload failed";
      }

      // 2. Submit Report with URL
      await supabase.from('reports').insert({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'link': fileUrl, // Store file URL in link column
        'campus_id': widget.campusId,
        'author_id': supabase.auth.currentUser!.id,
        'deadline_id': _selectedDeadlineId,
        'status': 'Submitted',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting report: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text("Submit Report"),
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
      ),
      body: _fetchingDeadlines
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Select Deadline",
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (_deadlines.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNavy,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.redAccent.withOpacity(0.5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.redAccent),
                          SizedBox(width: 10),
                          Expanded(
                              child: Text(
                                  "No active report submission windows found.",
                                  style: TextStyle(color: Colors.white))),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNavy,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDeadlineId,
                          dropdownColor: AppTheme.primaryNavy,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down,
                              color: Colors.white),
                          style: const TextStyle(color: Colors.white),
                          items: _deadlines.map((item) {
                            return DropdownMenuItem<String>(
                              value: item['id'],
                              child: Text(
                                  "${item['title']} (Due: ${item['due_date'].toString().split('T')[0]})"),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => _selectedDeadlineId = val),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  _buildTextField(
                      "Report Title", _titleController, Icons.title),
                  const SizedBox(height: 16),
                  _buildTextField(
                      "Description", _descriptionController, Icons.description,
                      maxLines: 5),

                  const SizedBox(height: 24),

                  // File Picker UI
                  const Text(
                    "Attach Document (PDF, Doc, Docx)",
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _pickFile,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNavy,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _selectedFile != null
                                ? AppTheme.accentBlue
                                : Colors.white24,
                            style: BorderStyle.solid),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedFile != null
                                ? Icons.check_circle
                                : Icons.upload_file,
                            color: _selectedFile != null
                                ? Colors.greenAccent
                                : Colors.white54,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedFile != null
                                      ? _selectedFile!.name
                                      : "Click to select a file",
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_selectedFile != null)
                                  Text(
                                    "${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB",
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 12),
                                  )
                              ],
                            ),
                          ),
                          if (_selectedFile != null)
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white54),
                              onPressed: () {
                                setState(() => _selectedFile = null);
                              },
                            )
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_loading || _deadlines.isEmpty)
                          ? null
                          : _submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading || _isUploading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2)),
                                const SizedBox(width: 12),
                                Text(_isUploading
                                    ? "Uploading..."
                                    : "Submitting...")
                              ],
                            )
                          : const Text("Submit Report",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, IconData icon,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: AppTheme.accentBlue),
        filled: true,
        fillColor: AppTheme.primaryNavy,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.accentBlue),
        ),
      ),
    );
  }
}
