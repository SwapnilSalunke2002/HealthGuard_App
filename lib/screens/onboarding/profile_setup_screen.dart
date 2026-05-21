import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

// Project Imports
import '../../data/health_ids.dart';
// Note: HealthPoint model import is not needed for ingestion service anymore,
// as the new service takes raw values directly.
import '../../services/health_ingestion_service.dart';
import '../../widgets/components.dart'; 
import '../../widgets/cyber_snackbar.dart'; 
import '../permissions_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final User user;
  const ProfileSetupScreen({super.key, required this.user});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currPage = 0;
  bool _isLoading = false;
  late AnimationController _pulseController;

  // --- FORM DATA ---
  final TextEditingController _fNameCtrl = TextEditingController();
  final TextEditingController _lNameCtrl = TextEditingController();
  final TextEditingController _heightCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();
  
  DateTime? _dob;
  String _gender = 'Male';
  
  // Fitness Profile
  String _dietType = 'Omnivore'; 
  final List<String> _workoutProtocols = []; 
  final List<String> _workoutOptions = ["Gym", "Home Workout", "Cardio", "Yoga", "CrossFit", "Athletics", "Calisthenics", "None"];
  
  // Chronic Conditions
  final List<String> _conditionsList = ["Diabetes", "Hypertension", "Asthma", "Heart Issue", "Thyroid", "None"];
  final List<String> _selectedConditions = [];

  // Habits
  bool _isSmoker = false;
  bool _drinksAlcohol = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pageController.dispose();
    _fNameCtrl.dispose();
    _lNameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  // --- ACTIONS ---

  void _nextPage() {
    FocusScope.of(context).unfocus();

    if (_currPage == 0) {
      if (_fNameCtrl.text.isEmpty || _lNameCtrl.text.isEmpty) {
        return _showError("Identity Protocol Incomplete.");
      }
      if (_dob == null) {
        return _showError("Date of Birth Required.");
      }
    } 
    else if (_currPage == 1) {
      if (_heightCtrl.text.isEmpty || _weightCtrl.text.isEmpty) {
        return _showError("Morphology Scan Required.");
      }
    }

    if (_currPage < 3) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      _finalizeSetup();
    }
  }

  void _previousPage() {
    FocusScope.of(context).unfocus();
    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _showError(String msg) {
    CyberSnackbar.show(context, msg, type: SnackbarType.warning);
  }

  Future<void> _finalizeSetup() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();

      // 1. Save Complete Profile Data to SUPABASE
      await Supabase.instance.client.from('users').upsert({
        'firebase_uid': widget.user.uid, // The crucial link
        'email': widget.user.email,
        'photo_url': widget.user.photoURL,
        'first_name': _fNameCtrl.text.trim(),
        'last_name': _lNameCtrl.text.trim(),
        'dob': _dob!.toIso8601String().split('T')[0], // YYYY-MM-DD
        'gender': _gender,
        'height': double.parse(_heightCtrl.text),
        'weight': double.parse(_weightCtrl.text),
        'chronic_conditions': _selectedConditions,
        'diet_type': _dietType,
        'workout_protocol': _workoutProtocols,
        'habits': {
          'smoking': _isSmoker, 
          'alcohol': _drinksAlcohol
        },
      }, onConflict: 'firebase_uid'); // Matches the stub created by AuthGate

      // 2. Log Initial Health Points into Time-Series 
      final ingestion = HealthIngestionService();
      
      await ingestion.logHealthData(
        metricId: HealthID.height,
        value: double.parse(_heightCtrl.text),
        timestamp: now,
        forceUid: widget.user.uid, // Guarantees it saves
      );

      await ingestion.logHealthData(
        metricId: HealthID.weight,
        value: double.parse(_weightCtrl.text),
        timestamp: now,
        forceUid: widget.user.uid, // Guarantees it saves
      );

      // 3. Move to Permissions
      if (mounted) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const PermissionsScreen())
        );
      }
    } catch (e) {
      if (mounted) {
        CyberSnackbar.show(context, "Critical Error: $e", type: SnackbarType.error);
        setState(() => _isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            const GlobalAnimatedBackground(),
            
            SafeArea(
              child: Column(
                children: [
                  // --- HEADER ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Row(
                      children: [
                        if (_currPage > 0) 
                          GestureDetector(
                            onTap: _previousPage, 
                            child: Container(padding: const EdgeInsets.all(8), color: Colors.transparent, child: const Icon(Icons.arrow_back, color: Colors.white54, size: 24))
                          ),
                        
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("SEQUENCE 0${_currPage + 1}/04", style: const TextStyle(color: AppColors.neonBlue, fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                              const SizedBox(height: 8),
                              Container(
                                height: 4,
                                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: (_currPage + 1) / 4,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.neonBlue, 
                                      borderRadius: BorderRadius.circular(2),
                                      boxShadow: [BoxShadow(color: AppColors.neonBlue.withOpacity(0.5), blurRadius: 6)]
                                    )
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- CONTENT ---
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(), 
                      onPageChanged: (i) => setState(() => _currPage = i),
                      children: [
                        _buildStep1Identity(),
                        _buildStep2Physique(),
                        _buildStep3Pathology(),
                        _buildStep4Protocols(),
                      ],
                    ),
                  ),

                  // --- ACTION BUTTON ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: GestureDetector(
                      onTap: _isLoading ? null : _nextPage,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) => Container(
                          height: 64, 
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xff1A232E), Color(0xff0D1318)]),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.neonBlue.withOpacity(0.5)),
                            boxShadow: [BoxShadow(color: AppColors.neonBlue.withOpacity(0.15 * _pulseController.value), blurRadius: 20)],
                          ),
                          child: Center(
                            child: _isLoading 
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                              : Text(
                                  _currPage == 3 ? "INITIALIZE SYSTEM" : "NEXT SEQUENCE", 
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =================================================================
  // 🔹 STEP 1: IDENTITY
  // =================================================================
  Widget _buildStep1Identity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Biological Profile", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w300)),
          const SizedBox(height: 8),
          Text("Required for accurate reference baselines.", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
          const SizedBox(height: 40),
          
          _CleanTextField(controller: _fNameCtrl, label: "First Name", icon: Icons.person_outline),
          const SizedBox(height: 24),
          _CleanTextField(controller: _lNameCtrl, label: "Last Name", icon: Icons.badge_outlined),
          const SizedBox(height: 32),

          // Gender Toggle
          Container(
             height: 60,
             decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
             child: Row(
               children: [
                 Expanded(child: GestureDetector(onTap: (){ FocusScope.of(context).unfocus(); setState(()=>_gender="Male"); }, child: Container(color: Colors.transparent, child: Center(child: Text("MALE", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1, color: _gender=="Male" ? AppColors.neonBlue : Colors.grey)))))),
                 Container(width: 1, height: 30, color: Colors.white10),
                 Expanded(child: GestureDetector(onTap: (){ FocusScope.of(context).unfocus(); setState(()=>_gender="Female"); }, child: Container(color: Colors.transparent, child: Center(child: Text("FEMALE", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1, color: _gender=="Female" ? AppColors.neonBlue : Colors.grey)))))),
               ],
             ),
           ),
           const SizedBox(height: 24),

           // Date Picker
           GestureDetector(
             onTap: () async {
               FocusScope.of(context).unfocus();
               final d = await showDatePicker(context: context, initialDate: DateTime(2000), firstDate: DateTime(1920), lastDate: DateTime.now(), builder: (c,child)=>Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.neonBlue)), child: child!));
               if(d!=null) setState(()=>_dob=d);
             },
             child: Container(
               height: 60,
               padding: const EdgeInsets.symmetric(horizontal: 20),
               decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: _dob!=null?AppColors.neonBlue:Colors.white10)),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text(_dob==null?"DATE OF BIRTH":"${DateFormat('dd MMM yyyy').format(_dob!)}", style: TextStyle(color: _dob!=null?Colors.white:Colors.white38, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                   Icon(Icons.calendar_today, color: _dob!=null?AppColors.neonBlue:Colors.white38, size: 20),
                 ],
               ),
             ),
           ),
        ],
      ),
    );
  }

  // =================================================================
  // 🔹 STEP 2: PHYSIQUE
  // =================================================================
  Widget _buildStep2Physique() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Physique", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w300)),
          const SizedBox(height: 8),
          Text("Calibrating Body Mass Index (BMI).", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
          const SizedBox(height: 60),

          Row(children: [
            Expanded(child: _BigNumberInput(controller: _heightCtrl, label: "HEIGHT", unit: "cm")),
            const SizedBox(width: 16),
            Expanded(child: _BigNumberInput(controller: _weightCtrl, label: "WEIGHT", unit: "kg")),
          ]),
          
          const SizedBox(height: 40),
          _SectionLabel("WORKOUT PROTOCOL"),
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 12, runSpacing: 12,
            children: _workoutOptions.map((style) {
              final isSelected = _workoutProtocols.contains(style);
              return FilterChip(
                label: Text(style.toUpperCase()),
                selected: isSelected,
                onSelected: (v) {
                  setState(() {
                    if (style == "None") {
                      _workoutProtocols.clear();
                      if (v) _workoutProtocols.add("None");
                    } else {
                      _workoutProtocols.remove("None");
                      v ? _workoutProtocols.add(style) : _workoutProtocols.remove(style);
                    }
                  });
                },
                selectedColor: AppColors.neonBlue.withOpacity(0.2),
                backgroundColor: Colors.white.withOpacity(0.05),
                checkmarkColor: AppColors.neonBlue,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                labelStyle: TextStyle(color: isSelected ? AppColors.neonBlue : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isSelected ? AppColors.neonBlue : Colors.transparent)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // =================================================================
  // 🔹 STEP 3: PATHOLOGY
  // =================================================================
  Widget _buildStep3Pathology() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Pathology Scan", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w300)),
          const SizedBox(height: 8),
          Text("Select existing diagnostics.", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
          const SizedBox(height: 40),

          Wrap(
            spacing: 12, runSpacing: 12,
            children: _conditionsList.map((condition) {
              final isSelected = _selectedConditions.contains(condition);
              return FilterChip(
                label: Text(condition),
                selected: isSelected,
                onSelected: (v) => setState(() {
                  if (condition == "None") {
                    _selectedConditions.clear();
                    if(v) _selectedConditions.add("None");
                  } else {
                    _selectedConditions.remove("None");
                    v ? _selectedConditions.add(condition) : _selectedConditions.remove(condition);
                  }
                }),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                backgroundColor: Colors.white.withOpacity(0.05),
                selectedColor: AppColors.signalRed.withOpacity(0.15),
                checkmarkColor: AppColors.signalRed,
                labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? AppColors.signalRed : Colors.white10)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // =================================================================
  // 🔹 STEP 4: PROTOCOLS
  // =================================================================
  Widget _buildStep4Protocols() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Life Protocols", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w300)),
          const SizedBox(height: 8),
          Text("Fuel source and habits.", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
          const SizedBox(height: 40),

          _SectionLabel("FUEL SOURCE"),
          const SizedBox(height: 16),
          Container(
            height: 100, 
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDietCard("Omnivore", Icons.restaurant),
                const SizedBox(width: 12),
                _buildDietCard("Vegetarian", Icons.spa),
                const SizedBox(width: 12),
                _buildDietCard("Vegan", Icons.grass),
              ],
            ),
          ),
          const SizedBox(height: 40),

          _SectionLabel("HABIT STACK"),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHabitToggle("SMOKER", Icons.smoking_rooms, _isSmoker, (v) => setState(() => _isSmoker = v)),
                Container(width: 1, height: 40, color: Colors.white10),
                _buildHabitToggle("ALCOHOL", Icons.local_bar, _drinksAlcohol, (v) => setState(() => _drinksAlcohol = v)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _SectionLabel(String title) {
    return Text(title, style: const TextStyle(color: AppColors.neonBlue, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold));
  }

  Widget _buildDietCard(String label, IconData icon) {
    bool isSelected = _dietType == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _dietType = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.neonBlue.withOpacity(0.15) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? AppColors.neonBlue : Colors.transparent, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? AppColors.neonBlue : Colors.grey, size: 28),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHabitToggle(String label, IconData icon, bool value, Function(bool) onTap) {
    return GestureDetector(
      onTap: () => onTap(!value),
      child: Column(
        children: [
          Icon(icon, color: value ? AppColors.signalRed : Colors.grey, size: 28),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: value ? AppColors.signalRed : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            width: 12, height: 12, 
            decoration: BoxDecoration(
              color: value ? AppColors.signalRed : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: value ? AppColors.signalRed : Colors.white24)
            )
          ),
        ],
      ),
    );
  }
}

class _BigNumberInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String unit;
  const _BigNumberInput({required this.controller, required this.label, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 8),
        Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                ),
              ),
              Text(unit, style: const TextStyle(color: AppColors.neonBlue, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CleanTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  const _CleanTextField({required this.controller, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 18),
      cursorColor: AppColors.neonBlue,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white38, fontSize: 16),
        prefixIcon: Icon(icon, color: Colors.white38),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.neonBlue, width: 2)),
      ),
    );
  }
}