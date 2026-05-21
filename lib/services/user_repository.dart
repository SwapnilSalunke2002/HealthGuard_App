import 'package:firebase_auth/firebase_auth.dart'; // <-- Fixed path
// Hide Supabase's 'User' class to prevent conflicts with Firebase's 'User'
import 'package:supabase_flutter/supabase_flutter.dart' hide User; // <-- Added 'hide User'

class UserRepository {
  // Use the Supabase client for database operations
  final SupabaseClient _supabase = Supabase.instance.client;

  /// 1. Check if the user has completed onboarding
  /// SAFEGUARD: If missing, creates a "stub" row to prevent Foreign Key crashes
  Future<bool> userExists(String uid, {String? email}) async {
    try {
      // Query Supabase to see if a row with this Firebase UID exists
      final data = await _supabase
          .from('users')
          .select('id, first_name') // Pull first_name to check if onboarding is actually done
          .eq('firebase_uid', uid)
          .maybeSingle(); // Returns null if no row is found

      if (data != null) {
        // If they have a first_name, they finished onboarding
        if (data['first_name'] != null) {
          print("✅ [UserRepository] User exists and is fully onboarded!");
          return true;
        } else {
          print("⚠️ [UserRepository] User stub exists, but onboarding incomplete.");
          return false;
        }
      }

      // --- THE SAFEGUARD ---
      // If no row exists at all, insert a stub so background tasks don't crash
      print("⚠️ [UserRepository] User missing in Supabase. Creating stub row...");
      await _supabase.from('users').insert({
        'firebase_uid': uid,
        if (email != null) 'email': email,
      });
      
      // Still return false so the UI knows to send them to the Profile Setup screen
      return false; 
      
    } catch (e) {
      print("❌ [UserRepository] Error checking user existence: $e");
      return false;
    }
  }

  /// 2. Save the FULL profile from the Onboarding Screen
  Future<void> saveUser(
    User user, {
    required String firstName,
    required String lastName,
    required DateTime dob,
    required String gender,
    required double height, // in cm
    required double weight, // in kg
  }) async {
    try {
      // We use upsert(). 
      // CRITICAL: We pass onConflict to tell Supabase to match the existing stub row!
      await _supabase.from('users').upsert({
        'firebase_uid': user.uid, 
        'email': user.email,
        'first_name': firstName,
        'last_name': lastName,
        'photo_url': user.photoURL,
        
        // Health/Demo Data
        'dob': dob.toIso8601String().split('T')[0], // Extract just the YYYY-MM-DD
        'gender': gender,
        'height': height,
        'weight': weight,
      }, onConflict: 'firebase_uid'); // <--- Tells SQL how to find the stub row
      
      print("✅ [UserRepository] User profile saved/updated in Supabase.");
    } catch (e) {
      print("❌ [UserRepository] Failed to save user: $e");
      rethrow; // Rethrow so your UI can show a CyberSnackbar
    }
  }

  /// 3. Stream user data for the Profile Screen
  /// Note: Returns a Map instead of a Firestore DocumentSnapshot
  Stream<Map<String, dynamic>> getUserStream(String uid) {
    return _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('firebase_uid', uid)
        .map((list) => list.isNotEmpty ? list.first : {});
  }
}