import 'dart:ui';
import 'package:HealthGuard/screens/profile_screen.dart';
import 'package:HealthGuard/screens/tabs/data_entry_tab.dart';
import 'package:HealthGuard/services/permission_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Import Components
import '../widgets/components.dart';

// Import Tabs
import 'tabs/dashboard_tab.dart';
import 'tabs/analytics_tab.dart';


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _auroraController;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    
    // 1. Initialize Animation
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);

    // 2. Trigger Permission Request (Wait a moment so UI renders first)
    Future.delayed(const Duration(seconds: 1), () {
      PermissionService().requestAllPermissions();
    });
  }

  @override
  void dispose() {
    _auroraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      resizeToAvoidBottomInset: false,
      extendBody: true,
      body: Stack(
        children: [
          // 1. USE SHARED BACKGROUND (Modular)
          const GlobalAnimatedBackground(), 
          
          // 2. CONTENT
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildTopBar(context), // Pass context
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: const [
                      DashboardTab(),
                      AnalyticsTab(),
                      DataEntryTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 3. DOCK
          Positioned(
            bottom: 18,
            left: 0,
            right: 0,
            child: Center(child: _buildMorphingGlassNav()),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    String displayName = _currentUser?.displayName ?? "User";
    String? photoUrl = _currentUser?.photoURL;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("SYSTEM ACTIVE", style: TextStyle(color: AppColors.signalGreen, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text("Hello, ${displayName.split(' ')[0]}", style: const TextStyle(color: AppColors.textWhite, fontSize: 20, fontWeight: FontWeight.w300, letterSpacing: -0.5)),
            ],
          ),
          
          // PROFILE NAVIGATION
          GestureDetector(
            onTap: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const ProfileScreen())
              );
            },
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Hero( // Adds smooth animation to profile screen
                tag: 'profile-avatar',
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null 
                    ? const Icon(Icons.person, color: AppColors.textGrey, size: 20) 
                    : null,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMorphingGlassNav() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xff1A232E),
                Color(0xff0D1318),
                Color(0xff1A232E),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.02),
                blurRadius: 20,
                spreadRadius: 0,
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _morphNavOneItem(Icons.grid_view_rounded, "Monitor", 0),
              const SizedBox(width: 5),
              _morphNavOneItem(Icons.insights_rounded, "Analytics", 1),
              const SizedBox(width: 5),
              _morphNavOneItem(Icons.label_important_outline_rounded, "Input", 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _morphNavOneItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: isSelected ? 110 : 55, 
        height: 45,
        decoration: isSelected 
          ? BoxDecoration(
              color: const Color(0xffffffff),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.lightBlueAccent.withOpacity(0.1)),
            ) 
          : const BoxDecoration(
              color: Colors.transparent,
            ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.bgDark : AppColors.textWhite,
              size: 20,
            ),
            if (isSelected) 
              Flexible( 
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: const TextStyle(
                      color: AppColors.bgDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}