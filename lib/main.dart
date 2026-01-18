import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/admin_home_screen.dart';
import 'screens/volunteer_home_screen.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';

final supabase = Supabase.instance.client;

/// ✅ MethodChannel talking to Android (MainActivity.kt)

/// ✅ MethodChannel talking to Android (MainActivity.kt)
const MethodChannel _nfcChannel = MethodChannel('com.example.csaapp/nfc_events');

/// ✅ Global Stream Controller for NFC events
final StreamController<String> _nfcController = StreamController.broadcast();

/// ✅ Public Stream for screens to listen to
Stream<String> get nfcStream => _nfcController.stream;

/// ✅ Initialize the NFC Listener once
void initNfcListener() {
  _nfcChannel.setMethodCallHandler((call) async {
    if (call.method == 'nfcData') {
      final String data = call.arguments.toString();
      debugPrint("✅ NFC RECEIVED IN FLUTTER → $data");
      _nfcController.add(data);
    }
    return;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Start listening to MethodChannel immediately
  initNfcListener();

  await Supabase.initialize(
    url: "https://uzowcoxxhucpwdxqucrq.supabase.co",
    anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV6b3djb3h4aHVjcHdkeHF1Y3JxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1MDk4NzMsImV4cCI6MjA3NzA4NTg3M30.3w-NDuS20GOcMsy01FjNf5lDLSNCSOjJ0u1M-r_c0mw",
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CSA App',
      theme: AppTheme.darkTheme,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    await Future.delayed(Duration.zero);
    final session = supabase.auth.currentSession;
    if (session == null) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()));
    } else {
       // Logged in — check role for redirection
       // Fetch role from DB
       try {
         final userData = await supabase
          .from("users")
          .select("role, campusId")
          .eq("id", session.user.id)
          .maybeSingle();

         if (!mounted) return;

         final role = userData?["role"] ?? "Volunteer";
         final campus = userData?["campusId"];

         if (role == "CohortRep" || role == "CampusHead" || role == "OverallHead") {
             Navigator.of(context).pushReplacement(
               MaterialPageRoute(builder: (_) => AdminHomeScreen(role: role, adminCampusId: campus)),
             );
         } else {
             Navigator.of(context).pushReplacement(
               MaterialPageRoute(builder: (_) => const VolunteerHomeScreen()),
             );
         }

       } catch(e) {
         // Error fetching role, maybe force logout or show login
         if (!mounted) return;
         Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()));
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
