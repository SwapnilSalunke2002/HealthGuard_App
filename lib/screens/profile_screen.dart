import 'dart:ui';
import 'package:HealthGuard/screens/login_screen.dart';
import 'package:HealthGuard/screens/onboarding/profile_setup_screen.dart';
import 'package:HealthGuard/widgets/consistency_heatmap.dart';
import 'package:flutter/material.dart';

// --- AUTH & DB IMPORTS ---
import 'package:firebase_auth/firebase_auth.dart';
// Hide Supabase's User to prevent conflict with Firebase Auth's User
import 'package:supabase_flutter/supabase_flutter.dart' hide User; 

// Services & Widgets
import '../../widgets/components.dart'; 
import '../../services/user_repository.dart';
import '../../services/auth_service.dart';
import '../../services/health_retrieval_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Services
  final UserRepository _userRepo = UserRepository();
  final HealthRetrievalService _retrievalService = HealthRetrievalService();

  // State
  late Future<List<DateTime>> _heatmapFuture;

  @override
  void initState() {
    super.initState();
    // Load last 105 days (15 weeks) for the heatmap
    _heatmapFuture = _retrievalService.getConsistencyDates(105);
  }

  // --- SUPABASE UPDATE LOGIC (Biometrics) ---
  Future<void> _updateBiometric(BuildContext context, String uid, String field, double value) async {
    try {
      // Direct update to the Supabase PostgreSQL database
      await Supabase.instance.client
          .from('users')
          .update({field: value})
          .eq('firebase_uid', uid); // Match the Firebase Auth ID
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Update Failed: $e"), backgroundColor: AppColors.signalRed));
      }
    }
  }

  void _showEditSheet(BuildContext context, String label, String field, String unit, double currentValue, String uid) {
    TextEditingController controller = TextEditingController(text: currentValue.toInt().toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 24, left: 24, right: 24),
        decoration: const BoxDecoration(
          color: Color(0xFF121212), 
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.white10, width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Row(children: [
              const Icon(Icons.edit, color: AppColors.neonBlue, size: 20),
              const SizedBox(width: 12),
              Text("Update $label", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 30),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              autofocus: true,
              cursorColor: AppColors.neonBlue,
              decoration: InputDecoration(
                suffixText: unit,
                suffixStyle: const TextStyle(color: AppColors.neonBlue, fontSize: 16),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.neonBlue)),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final newValue = double.tryParse(controller.text);
                  if (newValue != null) {
                    _updateBiometric(context, uid, field, newValue);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("SAVE UPDATE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          const GlobalAnimatedBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  // CHANGED: StreamBuilder now expects a Map, not a DocumentSnapshot
                  child: StreamBuilder<Map<String, dynamic>>(
                    stream: _userRepo.getUserStream(currentUser?.uid ?? ''),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.neonBlue, strokeWidth: 2));
                      
                      var data = snapshot.data!;
                      if (data.isEmpty) return const SizedBox();

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            _buildProfileHeader(data, currentUser),
                            
                            const SizedBox(height: 30),

                            // --- REAL DATA HEATMAP ---
                            FutureBuilder<List<DateTime>>(
                              future: _heatmapFuture,
                              builder: (context, heatSnapshot) {
                                if (heatSnapshot.connectionState == ConnectionState.waiting) {
                                  return Container(
                                    height: 120,
                                    width: double.infinity,
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(16)),
                                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textGrey)),
                                  );
                                }
                                if (heatSnapshot.hasError || !heatSnapshot.hasData) {
                                  return const ConsistencyHeatmap(logDates: []);
                                }
                                return ConsistencyHeatmap(logDates: heatSnapshot.data!);
                              },
                            ),
                            
                            const SizedBox(height: 24), 

                            _buildBiometricsLayout(context, data, currentUser!.uid),
                        
                            const SizedBox(height: 30),
                            _buildActionSection(context, data, currentUser), 
                            const SizedBox(height: 40),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), 
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05), 
                shape: BoxShape.circle, 
                border: Border.all(color: Colors.white.withOpacity(0.1))
              ),
              child: const Icon(Icons.arrow_back, color: AppColors.textWhite, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            "My Profile", 
            style: TextStyle(
              color: AppColors.textWhite, 
              fontSize: 20, 
              fontWeight: FontWeight.w300, 
              letterSpacing: 0.5
            )
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> data, User? currentUser) {
    // Uses 'photo_url' to match our Supabase schema
    String? photoUrl = data['photo_url'];
    if (photoUrl == null || photoUrl.isEmpty) photoUrl = currentUser?.photoURL;
    String initials = (data['first_name'] != null && data['first_name'].isNotEmpty) ? data['first_name'][0].toUpperCase() : "U";

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.neonBlue.withOpacity(0.5), width: 2),
            boxShadow: [BoxShadow(color: AppColors.neonBlue.withOpacity(0.2), blurRadius: 30, spreadRadius: 5)],
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.black,
            child: ClipOval(
              child: SizedBox(
                width: 100, height: 100,
                child: (photoUrl != null && photoUrl.isNotEmpty) 
                  ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (c,e,s) => Center(child: Text(initials, style: const TextStyle(color: AppColors.neonBlue, fontSize: 32, fontWeight: FontWeight.bold))))
                  : Center(child: Text(initials, style: const TextStyle(color: AppColors.neonBlue, fontSize: 32, fontWeight: FontWeight.bold))),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text("${data['first_name'] ?? ''} ${data['last_name'] ?? ''}", maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textWhite, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        ),
        const SizedBox(height: 6),
        if (currentUser?.email != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(currentUser!.email!, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textGrey, fontSize: 14, letterSpacing: 0.5)),
          ),
      ],
    );
  }

  Widget _buildBiometricsLayout(BuildContext context, Map<String, dynamic> data, String uid) {
    // CHANGED: Parse String Date instead of Firestore Timestamp
    final dobString = data['dob'] as String?;
    int age = 0;
    
    if (dobString != null) {
      try {
        final dob = DateTime.parse(dobString);
        final now = DateTime.now();
        age = now.year - dob.year;
        if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
          age--;
        }
      } catch (e) {
        age = 0; // Fallback if parse fails
      }
    }
    
    final height = (data['height'] is num) ? (data['height'] as num).toDouble() : 0.0;
    final weight = (data['weight'] is num) ? (data['weight'] as num).toDouble() : 0.0;
    final double heightM = height / 100;
    final double bmi = (height > 0 && weight > 0) ? (weight / (heightM * heightM)) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("BIOMETRICS", style: TextStyle(color: AppColors.textGrey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _buildCompactCard("Age", "$age", "years", Icons.cake_outlined, const Color(0xFFAB47BC), false, () {})),
          const SizedBox(width: 12),
          Expanded(child: _buildCompactCard("BMI", bmi.toStringAsFixed(1), _getBMILabel(bmi), Icons.monitor_weight_outlined, _getBMIColor(bmi), false, () {})),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _buildCompactCard("Height", "${height.toInt()}", "cm", Icons.height, AppColors.textWhite, true, () => _showEditSheet(context, "Height", "height", "cm", height, uid))),
          const SizedBox(width: 12),
          Expanded(child: _buildCompactCard("Weight", "${weight.toInt()}", "kg", Icons.scale_outlined, AppColors.textWhite, true, () => _showEditSheet(context, "Weight", "weight", "kg", weight, uid))),
        ]),
      ],
    );
  }

  Widget _buildCompactCard(String label, String value, String unit, IconData icon, Color color, bool isEditable, VoidCallback onTap) {
    return GestureDetector(
      onTap: isEditable ? onTap : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isEditable ? AppColors.neonBlue.withOpacity(0.3) : Colors.white.withOpacity(0.08)), 
            ),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [Text(value, style: const TextStyle(color: AppColors.textWhite, fontSize: 20, fontWeight: FontWeight.w600, height: 1.0)), const SizedBox(width: 4), Text(unit, style: const TextStyle(color: AppColors.textGrey, fontSize: 11))])),
                const SizedBox(height: 2),
                Row(children: [Text(label, style: const TextStyle(color: AppColors.textGrey, fontSize: 11, fontWeight: FontWeight.w500)), if (isEditable) ...[const SizedBox(width: 4), Icon(Icons.edit, color: AppColors.textGrey.withOpacity(0.5), size: 10)]]),
              ])),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildActionSection(BuildContext context, Map<String, dynamic> data, User currentUser) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("ACCOUNT", style: TextStyle(color: AppColors.textGrey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        _buildListTile(icon: Icons.calendar_today_outlined, title: "Member Since", subtitle: _formatDate(data['created_at'] as String?)),
        
        const SizedBox(height: 20),
        
        GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileSetupScreen(user: currentUser)));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03), 
              borderRadius: BorderRadius.circular(20), 
              border: Border.all(color: Colors.white.withOpacity(0.05)), 
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline_rounded, color: AppColors.neonBlue, size: 20),
                const SizedBox(width: 16),
                const Expanded(child: Text("Personal Details", style: TextStyle(color: AppColors.textWhite, fontSize: 14, fontWeight: FontWeight.w500))),
                Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textGrey.withOpacity(0.4), size: 12),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
        
        GestureDetector(
          onTap: () async {
            await AuthService().signOut();
            if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MyLogin()), (route) => false);
          },
          child: Container(
            height: 60, width: double.infinity,
            decoration: BoxDecoration(color: AppColors.signalRed.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.signalRed.withOpacity(0.2))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.logout, color: AppColors.signalRed, size: 20), SizedBox(width: 10), Text("Sign Out", style: TextStyle(color: AppColors.signalRed, fontSize: 15, fontWeight: FontWeight.bold))]),
          ),
        ),
      ],
    );
  }

  Widget _buildListTile({required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Row(children: [Icon(icon, color: AppColors.textGrey, size: 20), const SizedBox(width: 16), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: AppColors.textGrey, fontSize: 11)), Text(subtitle, style: const TextStyle(color: AppColors.textWhite, fontSize: 15, fontWeight: FontWeight.w500))])]),
    );
  }

  // CHANGED: Accepts String instead of Firestore Timestamp
  String _formatDate(String? dateString) { 
    if (dateString == null) return "Unknown"; 
    try {
      DateTime date = DateTime.parse(dateString); 
      return "${_monthName(date.month)} ${date.year}"; 
    } catch (e) {
      return "Unknown";
    }
  }
  
  String _monthName(int month) { const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]; if (month < 1 || month > 12) return ""; return months[month - 1]; }
  String _getBMILabel(double bmi) { if (bmi < 18.5) return "Under"; if (bmi < 25) return "Healthy"; if (bmi < 30) return "Over"; return "Obese"; }
  Color _getBMIColor(double bmi) { if (bmi < 18.5) return AppColors.signalYellow; if (bmi < 25) return AppColors.signalGreen; if (bmi < 30) return AppColors.signalYellow; return AppColors.signalRed; }
}