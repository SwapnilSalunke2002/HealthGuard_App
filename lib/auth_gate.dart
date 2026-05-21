import 'package:HealthGuard/screens/login_screen.dart';
import 'package:HealthGuard/screens/main_screen.dart';
import 'package:HealthGuard/screens/onboarding/profile_setup_screen.dart';
import 'package:HealthGuard/screens/permissions_screen.dart';
import 'package:HealthGuard/services/shared_prefs_service.dart';
import 'package:HealthGuard/widgets/components.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// NEW IMPORT:
import 'package:HealthGuard/services/user_repository.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        
        // 1. Waiting for Auth
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScaffold();
        }

        // 2. Not Logged In -> Login Screen
        if (!snapshot.hasData) {
          return const MyLogin(); 
        }

        User user = snapshot.data!;
        
        // 3. Logged In -> Check Supabase Profile via UserRepository
        return FutureBuilder<bool>(
          // This creates the "Stub" row if missing, and returns true if fully onboarded
          future: UserRepository().userExists(user.uid, email: user.email),
          builder: (context, userSnap) {
            
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const _LoadingScaffold();
            }

            // 4. ROUTING LOGIC
            final isFullyOnboarded = userSnap.data ?? false;

            if (isFullyOnboarded) {
              // --- PATH A: User Profile Exists ---
              bool isFirstLogin = SharedPrefsService().getBool('isFirstLogin', defaultValue: true);

              if (isFirstLogin) {
                return const PermissionsScreen(); // Force Permission Check
              } else {
                return const MainScreen(); // All good, go to Dashboard
              }

            } else {
              // --- PATH B: No Profile (New User) ---
              return ProfileSetupScreen(user: user); 
            }
          },
        );
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Center(child: CircularProgressIndicator(color: AppColors.neonBlue, strokeWidth: 2)),
    );
  }
}