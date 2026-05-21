import 'package:HealthGuard/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart'; // <--- ADD THIS IMPORT

// --- CONFIG & SERVICES ---
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'package:HealthGuard/services/health_registry.dart';
import 'package:HealthGuard/services/shared_prefs_service.dart';
import 'package:HealthGuard/services/silent_monitoring/silent_env_service.dart';
import 'package:HealthGuard/services/silent_monitoring/silent_health_service.dart';
import 'package:HealthGuard/services/task_orchestrator.dart';

// --- SCREENS & WIDGETS ---
import 'auth_gate.dart'; 
import 'widgets/components.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // 1. Setup Bindings & Hold Splash Screen
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding); // Holds the splash

  try {
    // 2. Critical Initialization (Splash screen stays visible during this)
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // 2. Initialize Supabase (Database)
    await Supabase.initialize(
      url: 'https://gqabufhnnzycdlgofvik.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdxYWJ1Zmhubnp5Y2RsZ29mdmlrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ4NTAxMzMsImV4cCI6MjA5MDQyNjEzM30.ob1XYVvf9Xl0XpZyMgPEAhnwQuoA_N4X39C_Zow0yRQ',
    );
    
    // UI System Overlay Settings
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // 3. Initialize Services
    await AuthService().init();
    await TaskOrchestrator().init(); 
    await HealthRegistry.initialize();
    await SharedPrefsService.init();

    bool isFirstLogin = SharedPrefsService().getBool('isFirstLogin') ?? true;
    if (!isFirstLogin) {
      await NotificationService.initialize();
    }

    // 4. Start Sensors (Foreground)
    SilentHealthService().init();
    SilentEnvService().init();
    
  } catch (e) {
    // If init fails, print error. The app might crash or show a blank screen, 
    // but the splash screen protected the startup phase.
    print("❌ CRITICAL INIT ERROR: $e");
  }

  // 5. Remove Splash & Run App
  // We remove the splash screen only when we are 100% ready to show UI
  FlutterNativeSplash.remove();
  
  runApp(const HealthGuardApp());
}

class HealthGuardApp extends StatelessWidget {
  const HealthGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealthGuard',
      debugShowCheckedModeBanner: false,

      // --- THEME CONFIGURATION ---
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bgDark, 
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlueAccent,
          surface: AppColors.bgDark, 
          primary: Colors.lightBlueAccent,
          secondary: const Color(0xffeeeeee),
          brightness: Brightness.dark,
        ),

        // Google Fonts (Lato)
        textTheme: GoogleFonts.latoTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ),

        // List Tile Theme
        listTileTheme: ListTileThemeData(
          titleTextStyle: GoogleFonts.lato(
            textStyle: ThemeData(
              brightness: Brightness.dark,
            ).textTheme.bodyLarge,
          ),
          subtitleTextStyle: GoogleFonts.lato(
            textStyle: ThemeData(
              brightness: Brightness.dark,
            ).textTheme.bodySmall,
          ),
        ),
      ),

      home: const AuthGate(),
    );
  }
}