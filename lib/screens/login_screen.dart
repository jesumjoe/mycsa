import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_home_screen.dart';
import 'volunteer_home_screen.dart';
import 'dart:async';
import '../main.dart' show nfcStream, supabase;
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _roll = TextEditingController();
  final _pass = TextEditingController();
  bool loading = false;
  bool showPass = false;
  bool _snackScheduled = false;
  StreamSubscription? _nfcSub;

  @override
  void initState() {
    super.initState();
    _nfcSub = nfcStream.listen((scannedData) {
      if (!mounted) return;
      setState(() => _roll.text = scannedData);

      if (_snackScheduled) return;
      _snackScheduled = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _snackScheduled = false; 
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Scanned: $scannedData"),
            duration: const Duration(seconds: 1),
            backgroundColor: AppTheme.accentBlue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _nfcSub?.cancel();
    super.dispose();
  }

  Future<void> login() async {
    if (_roll.text.isEmpty || _pass.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter roll number and password")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final res = await supabase.auth.signInWithPassword(
        email: "${_roll.text.trim()}@csa.app",
        password: _pass.text.trim(),
      );

      final userData = await supabase
          .from("users")
          .select("role, campusId")
          .eq("id", res.user!.id)
          .maybeSingle();

      if (!mounted) return;

      final role = userData?["role"] ?? "Volunteer";
      final campus = userData?["campusId"];

      if (role == "CohortRep" || role == "CampusHead" || role == "OverallHead") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AdminHomeScreen(
              role: role,
              adminCampusId: campus,
              adminCohortId: null,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VolunteerHomeScreen()),
        );
      }
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Login Failed: ${e.toString()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                // Logo or Icon placeholder
                Center(
                  child: Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNavy,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentBlue.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: const Icon(Icons.mic, size: 50, color: AppTheme.paleBlue), // Mic icon from WeTalk ref
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  "Login to Your Account",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Enter your credentials or scan your card",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.lightBlue,
                  ),
                ),
                const SizedBox(height: 48),

                // Inputs
                TextField(
                  controller: _roll,
                  decoration: const InputDecoration(
                    labelText: "Roll Number",
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _pass,
                  obscureText: !showPass,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => showPass = !showPass),
                    ),
                  ),
                ),
                
                // Remember me & Forgot Password (Visual only for now)
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: true, 
                          onChanged: (_) {},
                          fillColor: WidgetStateProperty.all(AppTheme.accentBlue),
                        ),
                        Text("Remember me", style: TextStyle(color: AppTheme.lightBlue)),
                      ],
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text("Forgot password?", style: TextStyle(color: AppTheme.accentBlue)),
                    )
                  ],
                ),

                const SizedBox(height: 30),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: loading ? null : login,
                    child: loading
                        ? const CircularProgressIndicator(color: AppTheme.white)
                        : const Text("Sign In"),
                  ),
                ),
                
                const SizedBox(height: 40),
                const Divider(color: AppTheme.primaryNavy),
                const SizedBox(height: 20),
                
                // Social Login placeholders (Visual)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _socialButton(Icons.nfc, () {}),
                    const SizedBox(width: 20),
                    _socialButton(Icons.fingerprint, () {}),
                  ],
                ),
                const SizedBox(height: 20),
                 Text(
                  "Use NFC or Biometrics",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.lightBlue.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _socialButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primaryNavy,
          border: Border.all(color: AppTheme.accentBlue.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: AppTheme.white, size: 28),
      ),
    );
  }
}