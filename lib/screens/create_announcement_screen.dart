import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/announcement_service.dart';
import '../theme/app_theme.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  final String adminRole;
  final String? adminCampusId;

  const CreateAnnouncementScreen({
    super.key,
    required this.adminRole,
    this.adminCampusId,
  });

  @override
  State<CreateAnnouncementScreen> createState() => _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = AnnouncementService();
  final _picker = ImagePicker();

  String _title = '';
  String _description = '';
  String _type = 'Event'; // Default
  String _targetCampus = 'All'; // Default for global if allowed
  bool _isGlobal = true;
  
  File? _selectedImage;
  bool _isUploading = false;

  final List<String> _campuses = ['BKC', 'CampusB', 'CampusC', 'CampusD'];

  @override
  void initState() {
    super.initState();
    // Enforce permissions on init
    if (widget.adminRole != 'OverallHead') {
      _isGlobal = false;
      _targetCampus = widget.adminCampusId ?? 'BKC';
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isUploading = true);

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _service.uploadPoster(_selectedImage!);
      }

      await _service.createAnnouncement(
        title: _title,
        description: _description,
        type: _type,
        isGlobal: _isGlobal,
        targetCampus: _isGlobal ? null : _targetCampus,
        imageUrl: imageUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement Posted Successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canToggleGlobal = widget.adminRole == 'OverallHead';

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text("New Announcement"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Type Selector
              Row(
                children: [
                  Expanded(
                    child: _buildTypeChip('Event', Icons.event),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTypeChip('Requirement', Icons.task_alt),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. Text Fields
              TextFormField(
                decoration: _inputDecoration("Title"),
                style: const TextStyle(color: Colors.white),
                validator: (v) => v!.isEmpty ? "Required" : null,
                onSaved: (v) => _title = v!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: _inputDecoration("Description").copyWith(alignLabelWithHint: true),
                style: const TextStyle(color: Colors.white),
                maxLines: 4,
                validator: (v) => v!.isEmpty ? "Required" : null,
                onSaved: (v) => _description = v!,
              ),
              const SizedBox(height: 24),

              // 3. Image Picker (Only for Events)
              if (_type == 'Event') ...[
                const Text("Event Poster", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickImage,
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNavy,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                      image: _selectedImage != null 
                        ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                        : null,
                    ),
                    child: _selectedImage == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, color: AppTheme.accentBlue, size: 32),
                              SizedBox(height: 8),
                              Text("Upload Poster", style: TextStyle(color: AppTheme.accentBlue)),
                            ],
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 4. Audience Settings
              const Text("Audience", style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                     SwitchListTile(
                       activeColor: AppTheme.accentBlue,
                       contentPadding: EdgeInsets.zero,
                       title: const Text("Global Announcement", style: TextStyle(color: Colors.white)),
                       subtitle: const Text("Post to all campuses", style: TextStyle(color: Colors.grey, fontSize: 12)),
                       value: _isGlobal, 
                       onChanged: canToggleGlobal 
                          ? (val) => setState(() => _isGlobal = val) 
                          : null, // Lock for CampusHeads
                     ),
                     if (!_isGlobal) ...[
                       const Divider(color: Colors.white12),
                       DropdownButtonFormField<String>(
                         value: _targetCampus,
                         dropdownColor: AppTheme.primaryNavy,
                         style: const TextStyle(color: Colors.white),
                         decoration: const InputDecoration(border: InputBorder.none),
                         items: _campuses.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                         onChanged: canToggleGlobal 
                            ? (val) => setState(() => _targetCampus = val!)
                            : null, // Read-only for CampusHeads (locked to own campus)
                       ),
                     ]
                  ],
                ),
              ),
              
              const SizedBox(height: 40),

              // 5. Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isUploading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text("Post $_type", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, IconData icon) {
    bool isSelected = _type == label;
    return GestureDetector(
      onTap: () => setState(() => _type = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentBlue : AppTheme.primaryNavy,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppTheme.accentBlue : Colors.white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.black : Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold
            )),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: AppTheme.primaryNavy,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.all(16),
    );
  }
}
