// TODO Implement this library.

// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Track the Google User locally since .currentUser is gone from the plugin
  GoogleSignInAccount? _googleUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // --- 1. INITIALIZATION ---
  Future<void> init() async {
    try {
      // Initialize the Singleton (Required in v7)
      await GoogleSignIn.instance.initialize();
      
      // Listen to auth events to keep our local _googleUser updated
      GoogleSignIn.instance.authenticationEvents.listen((event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          _googleUser = event.user;
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          _googleUser = null;
        }
      });
      
      print("✅ Google Sign-In Initialized");
    } catch (e) {
      print("❌ Google Init Error: $e");
    }
  }

  // --- 2. SIGN IN ---
  Future<User?> signInWithGoogle() async {
    try {
      // Trigger the Authentication Flow
      // authenticate() returns the user directly in v7
      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate(
      );

      if (googleUser == null) {
        print("⚠️ Google Sign-In Canceled");
        return null;
      }

      // Store it locally
      _googleUser = googleUser;

      // Get Auth Tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create Firebase Credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.idToken,
        idToken: googleAuth.idToken,
      );

      // Sign In to Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      print("✅ User Logged In: ${userCredential.user?.displayName}");
      return userCredential.user;

    } catch (e) {
      print("❌ Google Sign-In Error: $e");
      return null;
    }
  }

  // --- 3. SIGN OUT ---
  Future<void> signOut() async {
    try {
      // Disconnect clears the cache and forces account picker next time
      await GoogleSignIn.instance.disconnect(); 
      await _auth.signOut();
    } catch (e) {
      print("Error signing out: $e");
    }
  }
}