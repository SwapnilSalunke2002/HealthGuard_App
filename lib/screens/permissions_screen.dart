import 'dart:ui'; 
import 'dart:io'; 
import 'package:HealthGuard/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

// Project Imports
import '../../services/shared_prefs_service.dart';
import '../../widgets/components.dart'; 
import 'main_screen.dart'; 

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with SingleTickerProviderStateMixin {
  PermissionStatus _notificationStatus = PermissionStatus.denied;
  PermissionStatus _locationStatus = PermissionStatus.denied;
  PermissionStatus _micStatus = PermissionStatus.denied;
  PermissionStatus _bluetoothStatus = PermissionStatus.denied;
  PermissionStatus _activityStatus = PermissionStatus.denied; 
  PermissionStatus _mediaStatus = PermissionStatus.denied; 

  late AnimationController _btnController;
  bool _isLoading = false;
  bool _isGrantingAll = false;

  @override
  void initState() {
    super.initState();
    _checkInitialStatuses();
    
    _btnController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _btnController.dispose();
    super.dispose();
  }

  Future<void> _checkInitialStatuses() async {
    final notif = await Permission.notification.status;
    final loc = await Permission.locationWhenInUse.status;
    final mic = await Permission.microphone.status;
    final blue = await Permission.bluetoothScan.status;
    
    PermissionStatus activity = PermissionStatus.granted;
    if (Platform.isAndroid) activity = await Permission.activityRecognition.status;

    PermissionStatus media;
    if (Platform.isAndroid) {
      final photos = await Permission.photos.status;
      final storage = await Permission.storage.status;
      media = (photos.isGranted || storage.isGranted) ? PermissionStatus.granted : PermissionStatus.denied;
    } else {
      media = await Permission.photos.status; 
    }

    if (mounted) {
      setState(() {
        _notificationStatus = notif;
        _locationStatus = loc;
        _micStatus = mic;
        _bluetoothStatus = blue;
        _activityStatus = activity;
        _mediaStatus = media;
      });
    }
  }

  Future<void> _requestAllPermissions() async {
    setState(() => _isGrantingAll = true);
    
    List<Permission> perms = [
      Permission.notification,
      Permission.locationWhenInUse,
      Permission.microphone,
      Permission.bluetoothScan,
      Permission.activityRecognition,
    ];

    if (Platform.isAndroid) {
      perms.add(Permission.photos);
      perms.add(Permission.videos);
    } else {
      perms.add(Permission.photos);
    }

    await perms.request();
    await _checkInitialStatuses();
    
    // 🚀 THE FIX: If they hit "Grant All", setup the Push Token!
    if (_notificationStatus.isGranted) {
      await NotificationService.initialize();
    }
    
    setState(() => _isGrantingAll = false);
  }

  Future<void> _requestPermission(Permission permission, Function(PermissionStatus) onUpdate) async {
    final status = await permission.request();
    if (mounted) setState(() => onUpdate(status));
    
    // 🚀 THE FIX: If they tap the individual "Alerts" tile, setup the Push Token!
    if (permission == Permission.notification && status.isGranted) {
      await NotificationService.initialize();
    }
  }

  Future<void> _requestMediaPermission() async {
    PermissionStatus status;
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.photos, Permission.videos, Permission.storage 
      ].request();
      bool isAnyGranted = statuses.values.any((s) => s.isGranted);
      status = isAnyGranted ? PermissionStatus.granted : PermissionStatus.denied;
    } else {
      status = await Permission.photos.request();
    }
    if (mounted) setState(() => _mediaStatus = status);
  }

  // Future<void> _requestPermission(Permission permission, Function(PermissionStatus) onUpdate) async {
  //   final status = await permission.request();
  //   if (mounted) setState(() => onUpdate(status));
  // }

  Future<void> _completeSetup() async {
    setState(() => _isLoading = true);
    await SharedPrefsService().setBool('isFirstLogin', false);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool allGranted = _notificationStatus.isGranted && _locationStatus.isGranted && _micStatus.isGranted && 
                      _bluetoothStatus.isGranted && _activityStatus.isGranted && _mediaStatus.isGranted;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          const GlobalAnimatedBackground(),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  
                  // --- HEADER ---
                  Row(children: [
                    Container(height: 15, width: 2, color: AppColors.neonBlue),
                    const SizedBox(width: 12),
                    const Text("SYSTEM CALIBRATION", style: TextStyle(color: AppColors.neonBlue, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  const Text("Sensor Access", style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w300, letterSpacing: -1)),
                  const SizedBox(height: 8),
                  Text("Link your device sensors to enable full features.", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, height: 1.4)),

                  const SizedBox(height: 20),

                  // --- PERMISSION CARD (NO SCROLL) ---
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF121212).withOpacity(0.6), 
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildCompactTile(Icons.notifications_rounded, "Alerts", "Critical health notifications", _notificationStatus, () => _requestPermission(Permission.notification, (s) => _notificationStatus = s), isFirst: true),
                              _buildCompactTile(Icons.location_on_rounded, "Location", "Local AQI & Weather data", _locationStatus, () => _requestPermission(Permission.locationWhenInUse, (s) => _locationStatus = s)),
                              _buildCompactTile(Icons.graphic_eq_rounded, "Microphone", "Environmental noise analysis", _micStatus, () => _requestPermission(Permission.microphone, (s) => _micStatus = s)),
                              _buildCompactTile(Icons.directions_walk_rounded, "Physical Activity", "Step counting & movement", _activityStatus, () => _requestPermission(Permission.activityRecognition, (s) => _activityStatus = s)), // NEW ACTIVITY TILE
                              _buildCompactTile(Icons.bluetooth_audio_rounded, "Bluetooth", "Wearable device syncing", _bluetoothStatus, () => _requestPermission(Permission.bluetoothScan, (s) => _bluetoothStatus = s)),
                              _buildCompactTile(Icons.photo_library_rounded, "Medical Records", "Upload Photos & Videos", _mediaStatus, _requestMediaPermission, isLast: true),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- GRANT ALL BUTTON (SEPARATE) ---
                    GestureDetector(
                      onTap: _isGrantingAll ? null : _requestAllPermissions,
                      child: Container(
                        width: double.infinity,
                        height: 55,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: allGranted ? [AppColors.signalGreen.withOpacity(0.01), AppColors.signalGreen.withOpacity(0.01)] : [AppColors.neonBlue.withOpacity(0.2), AppColors.neonBlue.withOpacity(0.1)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color:allGranted ? Colors.transparent: AppColors.neonBlue.withOpacity(0.3)),
                          boxShadow: [BoxShadow(color: AppColors.neonBlue.withOpacity(0.1), blurRadius: 10, spreadRadius: 1)],
                        ),
                        child: Center(
                          child: _isGrantingAll
                            ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.neonBlue, strokeWidth: 2))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.done_all_rounded, color: allGranted ? AppColors.signalGreen.withOpacity(0.3): AppColors.neonBlue, size: 20),
                                  const SizedBox(width: 10),
                                  Text(allGranted ? "All Permissions Granted" :"GRANT ALL PERMISSIONS", style: const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13)),
                                ],
                              ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // --- BOTTOM ACTION ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Setup Complete", style: TextStyle(color: AppColors.textGrey.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      GestureDetector(
                        onTap: _isLoading ? null : _completeSetup,
                        child: AnimatedBuilder(
                          animation: _btnController,
                          builder: (context, child) {
                            final scale = 1.0 + (_btnController.value * 0.03);
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                height: 64, width: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(colors: [Color(0xff1A232E), Color(0xff0D1318), Color(0xff1A232E)]),
                                  border: Border.all(color: AppColors.neonBlue.withOpacity(0.3)),
                                  boxShadow: [BoxShadow(color: AppColors.neonBlue.withOpacity(0.15), blurRadius: 20, spreadRadius: 2)],
                                ),
                                child: _isLoading
                                  ? const Padding(padding: EdgeInsets.all(18.0), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                  : const Icon(Icons.check_rounded, color: AppColors.neonBlue, size: 28),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTile(IconData icon, String title, String subtitle, PermissionStatus status, VoidCallback onTap, {bool isFirst = false, bool isLast = false}) {
    final isGranted = status.isGranted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isGranted ? null : onTap, 
        borderRadius: BorderRadius.vertical(top: isFirst ? const Radius.circular(24) : Radius.zero, bottom: isLast ? const Radius.circular(24) : Radius.zero),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: isGranted ? AppColors.neonBlue.withOpacity(0.05) : null,
            border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isGranted ? AppColors.neonBlue.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                  boxShadow: isGranted ? [BoxShadow(color: AppColors.neonBlue.withOpacity(0.3), blurRadius: 10)] : [],
                ),
                child: Icon(icon, color: isGranted ? Colors.white : Colors.white38, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: isGranted ? Colors.white : Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isGranted
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.signalGreen, size: 24)
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(20)),
                        child: const Text("ALLOW", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}