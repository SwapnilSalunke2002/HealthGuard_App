import 'dart:ui';
import 'dart:math' as math; // Needed for the Grid
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../main.dart';
import '../services/auth_service.dart';

class MyLogin extends StatefulWidget {
  const MyLogin({super.key});

  @override
  State<MyLogin> createState() => _MyLoginState();
}

class _MyLoginState extends State<MyLogin> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  String _version = '';
  bool _isLoading = false;

  // Controllers for the "Aurora" background effect
  late AnimationController _auroraController1;
  late AnimationController _auroraController2;
  
  // Controller for the UI Entrance Animation (Fade + Slide Up)
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadVersion();

    // 1. Setup Aurora Animations
    _auroraController1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _auroraController2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);

    // 2. Setup Entrance Animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1), // Start slightly down
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    // Start entrance animation
    _entranceController.forward();
  }

  @override
  void dispose() {
    _auroraController1.dispose();
    _auroraController2.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  @override
  Widget build(BuildContext context) {
    const Color bgDark = Color(0xff040B0F); 
    const Color primaryAccent = Color(0xFF00E5FF); // Cyan
    const Color secondaryAccent = Color(0xFF7B61FF); // Soft Violet

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // --- 1. THE AURORA BACKGROUND ---
          
          // Blob 1: Cyan (Top Left)
          AnimatedBuilder(
            animation: _auroraController1,
            builder: (context, child) {
              return Positioned(
                top: -100 + (_auroraController1.value * 50),
                left: -100 + (_auroraController1.value * 30),
                child: Container(
                  height: 500,
                  width: 500,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        primaryAccent.withOpacity(0.15),
                        bgDark.withOpacity(0.0),
                      ],
                      radius: 0.6,
                    ),
                  ),
                ),
              );
            },
          ),

          // Blob 2: Violet (Bottom Right)
          AnimatedBuilder(
            animation: _auroraController2,
            builder: (context, child) {
              return Positioned(
                bottom: -100 + (_auroraController2.value * 40),
                right: -100 + (_auroraController2.value * 20),
                child: Container(
                  height: 600,
                  width: 600,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        secondaryAccent.withOpacity(0.1),
                        bgDark.withOpacity(0.0),
                      ],
                      radius: 0.6,
                    ),
                  ),
                ),
              );
            },
          ),

          // --- 2. THE TECH GRID (Texture) ---
          // This adds the "Medical/Precision" feel you were missing
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(color: Colors.white.withOpacity(0.03)),
            ),
          ),

          // --- 3. BLUR MESH ---
          // Blurs both the aurora and the grid slightly for depth
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(color: Colors.transparent),
          ),

          // --- 4. MAIN CONTENT (With Entrance Animation) ---
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      const Spacer(flex: 3),

                      // HERO LOGO
                      _buildGlassLogo(primaryAccent),
                      
                      const SizedBox(height: 40),

                      // TYPOGRAPHY
                      const Text(
                        "HealthGuard",
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                          letterSpacing: -1.0,
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      Text(
                        "Your Personal Context-Aware Health Guardian",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.7),
                          letterSpacing: 0.5,
                          height: 1.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      const Spacer(flex: 4),
                      
                      // LOGIN AREA
                      Column(
                        children: [
                          _buildGoogleButton(),
                          const SizedBox(height: 24),
                          _buildFooter(),
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // --- 5. LOADING OVERLAY ---
          if (_isLoading)
            Container(
              color: bgDark.withOpacity(0.9),
              child: const Center(
                child: CircularProgressIndicator(
                  color: primaryAccent, 
                  strokeWidth: 2
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassLogo(Color accent) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Sharper Gradient Border for "Crystal" effect
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.4), 
            Colors.white.withOpacity(0.05),
          ],
          stops: const [0.1, 0.4],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.1),
            blurRadius: 50,
            spreadRadius: 10,
          )
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Colors.white.withOpacity(0.05),
            // padding: const EdgeInsets.all(28),
            child: Image.asset('assets/icons/healthguard_logo.png',height: 100,)
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // Glow behind the button
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.15),
            blurRadius: 25,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () async {
            setState(() => _isLoading = true);
            
            // Just sign in. 
            // The AuthGate in main.dart is listening to this stream 
            // and will automatically redirect the user once this completes.
            await _authService.signInWithGoogle();
            
            // No need to navigate manually here!
            // But if sign in failed, stop loading:
            if (mounted) setState(() => _isLoading = false);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 60,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/icons/google.png',
                  height: 24,
                  errorBuilder: (context, error, stackTrace) => 
                    const Icon(Icons.login, color: Colors.black, size: 24),
                ),
                const SizedBox(width: 14),
                const Text(
                  "Continue with Google",
                  style: TextStyle(
                    color: Color(0xff040B0F),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.verified_user_outlined, size: 14, color: Colors.white.withOpacity(0.4)),
        const SizedBox(width: 8),
        Text(
          "Secure Enterprise Gateway v$_version",
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// --- CUSTOM PAINTER FOR THE BACKGROUND GRID ---
class GridPainter extends CustomPainter {
  final Color color;
  GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    const double gridSize = 40.0; // Size of the squares

    // Draw Vertical Lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw Horizontal Lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}