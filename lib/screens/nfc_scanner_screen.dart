import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:flutter_animate/flutter_animate.dart';
import '../main.dart'; // supabase client & nfcStream
import '../theme/app_theme.dart';

class NfcScannerPage extends StatefulWidget {
  const NfcScannerPage({super.key});

  @override
  State<NfcScannerPage> createState() => _NfcScannerPageState();
}

class _NfcScannerPageState extends State<NfcScannerPage>
    with SingleTickerProviderStateMixin {
  StreamSubscription? _streamSub;
  String status = "Ready to Scan";
  String subStatus = "Hold card near back of device";

  bool isScanning = false;
  late AnimationController _sonarController;

  // Cache Admin Data
  String? _adminRole;
  String? _campusId;
  String? _adminId;

  @override
  void initState() {
    super.initState();
    _fetchAdminData();
    _subscribeToNfc();

    // Continuous Sonar Animation
    _sonarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  Future<void> _fetchAdminData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        _adminId = user.id;
        final data = await supabase
            .from('users')
            .select('role, campusId')
            .eq('id', user.id)
            .maybeSingle(); // Use maybeSingle to avoid crash if not found

        if (mounted && data != null) {
          setState(() {
            _adminRole = data['role'];
            _campusId = data['campusId'];
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching admin data: $e");
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _sonarController.dispose();
    super.dispose();
  }

  void _subscribeToNfc() {
    _streamSub = nfcStream.listen(
      (event) async {
        if (!mounted) return;
        debugPrint("⚡ Event: $event");
        HapticFeedback.lightImpact(); // Haptic Tick for detection

        setState(() {
          isScanning = true;
          status = "Processing...";
        });

        try {
          final String rawData = event.toString().trim();
          String registerNumber = rawData;

          final digitMatch = RegExp(r'\b\d{7}\b').firstMatch(rawData);
          if (digitMatch != null) {
            registerNumber = digitMatch.group(0)!;
          } else {
            if (RegExp(r'^\d+$').hasMatch(rawData)) {
              registerNumber = rawData;
            }
          }

          if (registerNumber.isEmpty) throw "No Register Number found";

          // Ensure Admin Data is Loaded
          if (_adminId == null || _adminRole == null) {
            await _fetchAdminData();
            if (_adminId == null) throw "Admin session invalid";
          }

          // Determine Punch Type
          String scanType = "in";
          final lastScan = await supabase
              .from('attendance_logs')
              .select('scanType, timestamp')
              .eq('registerNumber', registerNumber)
              .order('timestamp', ascending: false)
              .limit(1)
              .maybeSingle(); // Use maybeSingle

          if (lastScan != null) {
            scanType = lastScan['scanType'] == "in" ? "out" : "in";
          }

          // Insert Log
          await supabase.from('attendance_logs').insert({
            'registerNumber': registerNumber,
            'scanType': scanType,
            'scannedByUID': _adminId,
            'adminRole': _adminRole,
            'campusId': _campusId,
          });

          // Calculate Duration if OUT
          Duration? duration;
          if (scanType == "out" && lastScan != null) {
            final lastTime = DateTime.parse(lastScan['timestamp']).toLocal();
            duration = DateTime.now().difference(lastTime);
          }

          HapticFeedback.heavyImpact(); // Success Vibration
          _showCustomPopup(true, registerNumber, scanType, duration);
        } catch (e) {
          debugPrint("Error: $e");
          HapticFeedback.vibrate(); // Error Vibration
          _showCustomPopup(false, e.toString(), "", null);
        } finally {
          if (mounted) {
            setState(() {
              isScanning = false;
              status = "Ready to Scan";
            });
          }
        }
      },
      onError: (err) => debugPrint("Stream Error: $err"),
    );
  }

  // Refined Dark Card Popup (Matches Reference)
  void _showCustomPopup(
      bool success, String title, String type, Duration? duration) {
    // Capture time immediately
    final nowStr = DateFormat('h:mm a').format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: true, // Allow clicking outside
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF101426), // Dark background from reference
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Close Button (Top Right)
                Positioned(
                  right: -10,
                  top: -10,
                  child: IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),

                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),

                    // Success Icon
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: success
                            ? const Color(0xFF24D148)
                            : const Color(0xFFFF4848), // Bright Green/Red
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        success ? Icons.check_rounded : Icons.close_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    )
                        .animate()
                        .scale(duration: 400.ms, curve: Curves.elasticOut),

                    const SizedBox(height: 24),

                    // Title
                    Text(
                      success ? "Scan Successful" : "Scan Failed",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Subtitle / Description
                    Text(
                      success
                          ? "$title has been marked ${type.toUpperCase()}"
                          : "Could not register scan.\n$title",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),

                    // Timestamp (NEW)
                    if (success)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          "Time: $nowStr",
                          style: const TextStyle(
                            color: AppTheme.accentBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),

                    // Duration or Loading Spinner Placeholder
                    if (success && duration != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "⏱ Work: ${duration.inHours}h ${duration.inMinutes % 60}m",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                      )
                    else if (!success)
                      const SizedBox.shrink()
                    else
                      const SizedBox
                          .shrink(), // No spinner needed here since it's already done
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Glow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                  gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.8,
                colors: [
                  AppTheme.primaryNavy.withOpacity(0.2),
                  AppTheme.backgroundDark
                ],
              )),
            ),
          ),

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Sonar Animation Widget
              Center(
                child: CustomPaint(
                  painter: SonarPainter(_sonarController,
                      color: isScanning ? Colors.green : AppTheme.accentBlue),
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNavy,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              (isScanning ? Colors.green : AppTheme.accentBlue)
                                  .withOpacity(0.3),
                          blurRadius: 20,
                        )
                      ],
                    ),
                    child: Icon(Icons.nfc,
                        size: 60,
                        color: isScanning
                            ? Colors.greenAccent
                            : AppTheme.paleBlue),
                  ),
                ),
              ),

              const SizedBox(height: 80),

              Text(
                status,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1),
              ).animate(target: isScanning ? 1 : 0).shimmer(),

              const SizedBox(height: 10),
              Text(
                subStatus,
                style: TextStyle(color: AppTheme.lightBlue.withOpacity(0.6)),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ],
      ),
    );
  }
}

// Custom Painter for Ripple Effect
class SonarPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  SonarPainter(this.animation, {required this.color})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw 3 expanding circles
    for (int i = 0; i < 3; i++) {
      // Stagger animations: (value + offset) % 1.0
      double progress = (animation.value + (i * 0.35)) % 1.0;
      double radius = (size.width / 2) + (progress * 100);
      double opacity = 1.0 - progress;

      paint.color = color.withOpacity(opacity);
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SonarPainter oldDelegate) => true;
}
