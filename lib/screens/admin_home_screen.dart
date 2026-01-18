import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../main.dart'; // Import for supabase client
import 'attendance_logs_screen.dart'; // Import Attendance Logs Screen
import 'login_screen.dart'; // Import for logout navigation
import 'nfc_scanner_screen.dart'; // <-- CORRECTED IMPORT
import 'manage_volunteers_screen.dart';
import 'create_announcement_screen.dart';
import '../theme/app_theme.dart';

class AdminHomeScreen extends StatelessWidget {
  final String role;
  final String? adminCampusId;
  final String? adminCohortId;

  const AdminHomeScreen({
    super.key,
    required this.role,
    this.adminCampusId,
    this.adminCohortId,
  });

  // Logout function
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Banner
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryNavy, Color(0xFF0A3A80)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentBlue.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Welcome back,",
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppTheme.paleBlue.withOpacity(0.8),
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            role,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.white,
                                ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => _logout(context),
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.logout, color: AppTheme.white, size: 24),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0),
              
              const SizedBox(height: 40),
              
              Text(
                "Quick Actions",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.white,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(delay: 200.ms).slideX(),
              
              const SizedBox(height: 20),

              // Vertically Staggered List
              Column(
                children: [
                  _buildPremiumActionCard(
                    context,
                    title: "Scan Attendance",
                    subtitle: "Start a new NFC scanning session",
                    icon: Icons.nfc,
                    gradientColors: [AppTheme.accentBlue, AppTheme.lightBlue],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => NfcScannerPage()),
                      );
                    },
                    delay: 300,
                  ),
                  _buildPremiumActionCard(
                    context,
                    title: "Attendance Logs",
                    subtitle: "View history and export reports",
                    icon: Icons.history,
                    gradientColors: [const Color(0xFF4A6fa5), const Color(0xFF6B8cb3)],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AttendanceLogsScreen(
                            role: role,
                            campusId: adminCampusId,
                          ),
                        ),
                      );
                    },
                    delay: 400,
                  ),
                  _buildPremiumActionCard(
                    context,
                    title: "Announce",
                    subtitle: "Post Events or Needs",
                    icon: Icons.campaign_rounded,
                    gradientColors: [Colors.orange, Colors.deepOrange],
                    onTap: () {
                       Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CreateAnnouncementScreen(
                          adminRole: role,
                          adminCampusId: adminCampusId,
                        )),
                      );
                    },
                    delay: 450,
                  ),
                  _buildPremiumActionCard(
                    context,
                    title: "Manage Volunteers",
                    subtitle: "Add or remove team members",
                    icon: Icons.people_outline,
                    gradientColors: [const Color(0xFF2d4e75), const Color(0xFF43658f)],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ManageVolunteersScreen(
                            adminRole: role,
                            adminCampusId: adminCampusId,
                            adminCohortId: adminCohortId,
                          ),
                        ),
                      );
                    },
                    delay: 500,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    required int delay,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.primaryNavy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors.last.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppTheme.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppTheme.lightBlue.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppTheme.white.withOpacity(0.3)),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: delay.ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
  }
}