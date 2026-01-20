import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart'; // supabase client

class AnnouncementService {
  
  /// Uploads an image file to the 'posters' bucket and returns the Public URL.
  /// Returns null if user cancels or upload fails.
  Future<String?> uploadPoster(File imageFile) async {
    try {
      final String fileName = 'poster_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String path = 'public/$fileName';

      await supabase.storage.from('posters').upload(
        path,
        imageFile,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      final String publicUrl = supabase.storage.from('posters').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      throw Exception("Image upload failed: $e");
    }
  }

  /// Creates a new announcement record in the database.
  Future<void> createAnnouncement({
    required String title,
    required String description,
    required String type, // 'Event' or 'Requirement'
    required bool isGlobal,
    String? targetCampus,
    String? imageUrl,
    DateTime? deadline, // New Field
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    await supabase.from('announcements').insert({
      'title': title,
      'description': description,
      'type': type,
      'is_global': isGlobal,
      'target_campus': targetCampus,
      'image_url': imageUrl,
      'author_uid': user.id,
      'deadline': deadline?.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
