import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

void showComingSoonDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.primaryNavy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(24),
      title: const Row(
        children: [
          Icon(Icons.construction, color: Colors.orangeAccent),
          SizedBox(width: 10),
          Text("Coming Soon",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
      content: const Text(
        "This feature is currently under development. Stay tuned for updates!",
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Got it",
              style: TextStyle(color: AppTheme.accentBlue)),
        ),
      ],
    ),
  );
}
