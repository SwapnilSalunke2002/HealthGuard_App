import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Project Imports
import '../../services/health_registry.dart';
import '../../services/health_ingestion_service.dart'; 
import '../../models/health_point.dart'; 
import '../../data/health_ids.dart';
import '../../widgets/components.dart';
import '../../widgets/cyber_snackbar.dart';

class CyberAnalysisScreen extends StatefulWidget {
  final File file;
  final String fileType; 

  const CyberAnalysisScreen({super.key, required this.file, required this.fileType});

  @override
  State<CyberAnalysisScreen> createState() => _CyberAnalysisScreenState();
}

class _CyberAnalysisScreenState extends State<CyberAnalysisScreen> with TickerProviderStateMixin {
  
  bool _isAnalyzing = false;
  final List<String> _logs = [];
  final ScrollController _logScroll = ScrollController();
  
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;
  late AnimationController _btnController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _scanController, curve: Curves.easeInOut));
    _btnController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

    _addLog("SYSTEM INITIALIZED");
    _addLog("TARGET: ${widget.fileType.toUpperCase()}");
  }

  @override
  void dispose() {
    _scanController.dispose();
    _btnController.dispose();
    _logScroll.dispose();
    super.dispose();
  }

  void _addLog(String message) {
    if (!mounted) return;
    setState(() => _logs.add("> ${DateTime.now().second}.${DateTime.now().millisecond.toString().padLeft(3,'0')} $message"));
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _logScroll.hasClients) _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
    });
  }

  Future<void> _processFile() async {
    if (!mounted) return;
    setState(() => _isAnalyzing = true);
    _scanController.repeat(reverse: true); 
    _addLog("--- INITIATING UPLINK SEQUENCE ---");

    try {
      // 1. Upload
      _addLog("ENCRYPTING PAYLOAD...");
      String fileName = "scans/${DateTime.now().millisecondsSinceEpoch}_${widget.file.path.split('/').last}";
      Reference ref = FirebaseStorage.instance.ref().child(fileName);
      TaskSnapshot snapshot = await ref.putFile(widget.file);
      String downloadUrl = await snapshot.ref.getDownloadURL();
      _addLog("UPLOAD COMPLETE.");

      // 2. AI Analysis
      _addLog("CONNECTING TO LLAMA-4 SCOUT...");
      final result = await FirebaseFunctions.instance.httpsCallable('analyze_health_image').call({'imageUrl': downloadUrl});
      
      final cleanData = jsonDecode(jsonEncode(result.data)) as Map<String, dynamic>;
      
      if (cleanData['found'] == true) {
        _addLog("BIOMETRICS DETECTED.");
        if (mounted) {
           _scanController.stop();
           setState(() => _isAnalyzing = false);
           _showResultsSheet(cleanData);
        }
      } else {
        throw "No legible data found.";
      }

    } catch (e) {
      if (!mounted) return;
      _addLog("CRITICAL FAILURE: $e");
      _scanController.stop();
      setState(() => _isAnalyzing = false);
      CyberSnackbar.show(context, "SCAN FAILED", type: SnackbarType.error);
    }
  }

  void _showResultsSheet(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CyberResultSheet(data: data),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false, 
      body: Stack(
        children: [
          // 1. Content Layer
          Positioned.fill(
            child: widget.fileType == 'image'
                ? ColorFiltered(
                    colorFilter: _isAnalyzing 
                        ? const ColorFilter.mode(Colors.black54, BlendMode.darken) 
                        : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                    child: Image.file(widget.file, fit: BoxFit.cover),
                  )
                : _buildFilePreview(),
          ),
          
          // 2. Grid Overlay
          Positioned.fill(child: CustomPaint(painter: GridPainter(color: AppColors.neonBlue.withOpacity(0.05)))),

          // 3. Scanner Line
          if (_isAnalyzing)
            AnimatedBuilder(
              animation: _scanAnimation,
              builder: (context, child) {
                return Align(
                  alignment: Alignment(0, (_scanAnimation.value * 2) - 1),
                  child: Container(
                    height: 2,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.neonBlue,
                      boxShadow: const [
                        BoxShadow(color: AppColors.neonBlue, blurRadius: 10, spreadRadius: 1)
                      ],
                    ),
                  ),
                );
              },
            ),

          // 4. Bottom Controls
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 30, left: 24, right: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter, 
                  colors: [Colors.black.withOpacity(0.95), Colors.transparent]
                )
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 100,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                      child: ListView.builder(
                        controller: _logScroll,
                        itemCount: _logs.length,
                        itemBuilder: (context, index) => Text(_logs[index], style: const TextStyle(color: AppColors.neonBlue, fontFamily: 'Courier', fontSize: 10)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    if (!_isAnalyzing)
                      GestureDetector(
                        onTap: _processFile,
                        child: AnimatedBuilder(
                          animation: _btnController,
                          builder: (context, child) => Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            margin: const EdgeInsets.only(bottom: 20), 
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xff1A232E), Color(0xff0D1318)]),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.neonBlue.withOpacity(0.5)),
                              boxShadow: [BoxShadow(color: AppColors.neonBlue.withOpacity(0.2 * _btnController.value), blurRadius: 15)],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.radar_rounded, color: Colors.white.withOpacity(0.9), size: 20),
                                const SizedBox(width: 10),
                                const Text("INITIATE SCAN", style: TextStyle(color: Colors.white, letterSpacing: 2, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          
          Positioned(
            top: 50, left: 24, 
            child: GestureDetector(
              onTap: ()=>Navigator.pop(context), 
              child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.arrow_back, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // --- FILE PREVIEW WIDGET ---
  Widget _buildFilePreview() {
    String name = widget.file.path.split('/').last;
    String ext = name.split('.').last.toUpperCase();
    IconData icon = ext.contains('PDF') ? Icons.picture_as_pdf : Icons.description;
    int sizeBytes = widget.file.lengthSync();
    String sizeStr = (sizeBytes / 1024).toStringAsFixed(1) + " KB";

    return Center(
      child: SingleChildScrollView(
        child: Container(
          width: 240, 
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0F14), 
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.neonBlue.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 40, spreadRadius: 10), 
              BoxShadow(color: AppColors.neonBlue.withOpacity(0.1), blurRadius: 20)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppColors.neonBlue.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, size: 40, color: AppColors.neonBlue),
              ),
              const SizedBox(height: 24),
              Text(ext, style: const TextStyle(color: AppColors.neonBlue, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 12),
              
              Text(
                name, 
                textAlign: TextAlign.center, 
                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
              ),
              
              const SizedBox(height: 8),
              Text(sizeStr, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 24),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(6)), 
                child: const Text("READY FOR UPLINK", style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1.5))
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =================================================================
// 🚀 CYBER RESULT SHEET (Saving Logic Updated)
// =================================================================
class _CyberResultSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  const _CyberResultSheet({required this.data});

  @override
  State<_CyberResultSheet> createState() => _CyberResultSheetState();
}

class _CyberResultSheetState extends State<_CyberResultSheet> {
  late List<Map<String, dynamic>> coreMetrics;
  late List<Map<String, dynamic>> extraMetrics;
  final Map<int, bool> _selectedExtras = {};
  
  String? _userName;
  String _userAge = "--";
  String _userSex = "--";
  bool _isLoadingProfile = true;
  bool _isAllSelected = false;

  @override
  void initState() {
    super.initState();
    _sortData();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Query Supabase instead of Firestore
        final doc = await Supabase.instance.client
            .from('users')
            .select()
            .eq('firebase_uid', user.uid)
            .maybeSingle();

        if (doc != null) {
          if (mounted) {
            setState(() {
              final fName = doc['first_name'] as String?;
              final lName = doc['last_name'] as String?;
              if (fName != null && fName.isNotEmpty) {
                 _userName = "$fName ${lName ?? ''}".trim();
              } else {
                 _userName = null;
              }
              _userSex = doc['gender'] ?? "--";
              
              // FIX: Parse as String
              if (doc['dob'] != null) {
                try {
                  DateTime dob = DateTime.parse(doc['dob'].toString());
                  int age = DateTime.now().year - dob.year;
                  _userAge = "$age yrs";
                } catch (_) {
                  _userAge = "--";
                }
              }
              _isLoadingProfile = false;
            });
          }
        }
      }
    } catch (e) {
      if(mounted) setState(() => _isLoadingProfile = false);
    }
  }

  void _sortData() {
    coreMetrics = [];
    extraMetrics = [];
    final rawItems = List<Map<String, dynamic>>.from(widget.data['data'] ?? []);

    for (var i = 0; i < rawItems.length; i++) {
      var item = rawItems[i];
      if (item['value'] == null || item['value'].toString().toLowerCase() == 'null' || item['value'].toString().isEmpty) continue;

      String rawId = item['id'].toString();
      String stdId = HealthRegistry.resolveId(rawId);
      item['id'] = stdId; 

      if (HealthRegistry.get(stdId) != null) {
        coreMetrics.add(item);
      } else {
        item['_index'] = i; 
        extraMetrics.add(item);
        _selectedExtras[i] = false; 
      }
    }
  }

  void _toggleSelectAll() {
    setState(() {
      _isAllSelected = !_isAllSelected;
      for (var item in extraMetrics) {
        _selectedExtras[item['_index']] = _isAllSelected;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final labName = widget.data['lab_name'];
    final reportDate = widget.data['report_date'];

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F14), 
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: AppColors.neonBlue.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: AppColors.neonBlue.withOpacity(0.15), blurRadius: 40)],
      ),
      child: Column(
        children: [
          Center(child: Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.neonBlue.withOpacity(0.1), Colors.transparent], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.neonBlue.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text("SCAN REPORT", style: TextStyle(color: AppColors.neonBlue, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
                  Icon(Icons.verified_user_outlined, color: AppColors.neonBlue, size: 16),
                ]),
                const SizedBox(height: 12),
                
                if (_userName != null || _isLoadingProfile) ...[
                  Row(children: [
                    CircleAvatar(radius: 20, backgroundColor: Colors.white10, child: Icon(Icons.person, color: Colors.white70)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _isLoadingProfile 
                          ? Container(width: 80, height: 14, color: Colors.white10) 
                          : Text(_userName!, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      _isLoadingProfile 
                          ? Container(width: 60, height: 10, color: Colors.white10) 
                          : Text("$_userAge • $_userSex", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                    ])),
                  ]),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 12),
                ],
                
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (labName != null) _buildMetaBadge(Icons.science, labName),
                    if (reportDate != null) _buildMetaBadge(Icons.calendar_today, reportDate),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              children: [
                if (coreMetrics.isNotEmpty) ...[
                  _buildSectionHeader("HEALTH METRICS", AppColors.signalGreen),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.4, crossAxisSpacing: 10, mainAxisSpacing: 10),
                    itemCount: coreMetrics.length,
                    itemBuilder: (ctx, i) => _buildCoreTile(coreMetrics[i]),
                  ),
                  const SizedBox(height: 24),
                ],
                
                if (extraMetrics.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader("ADDITIONAL DATA", Colors.orange),
                      GestureDetector(
                        onTap: _toggleSelectAll,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _isAllSelected ? "Uncheck All" : "Select All",
                            style: const TextStyle(color: AppColors.neonBlue, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  Container(
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                    child: Column(children: extraMetrics.map((item) => _buildExtraTile(item)).toList()),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),

          Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
            decoration: BoxDecoration(color: const Color(0xFF0F0F0F), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1)))),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: AppColors.signalRed.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("DISCARD", style: TextStyle(color: AppColors.signalRed, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _saveData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.signalGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text("ACCEPT & SAVE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white54),
          const SizedBox(width: 6),
          Flexible(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Courier'), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(width: 4, height: 14, color: color, margin: const EdgeInsets.only(right: 8)),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      ]),
    );
  }

  Widget _buildCoreTile(Map<String, dynamic> item) {
    String id = item['id'].toString().toLowerCase();
    final def = HealthRegistry.get(id)!; 
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [def.color.withOpacity(0.15), Colors.transparent], begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: def.color.withOpacity(0.3), width: 1),
      ),
      child: Row(children: [
        Icon(def.icon, color: def.color, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(def.label.toUpperCase(), style: TextStyle(color: def.color.withOpacity(0.8), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          RichText(text: TextSpan(children: [
            TextSpan(text: "${item['value']} ", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
            TextSpan(text: def.unit, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
          ]), overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }

  Widget _buildExtraTile(Map<String, dynamic> item) {
    int index = item['_index'];
    bool isSelected = _selectedExtras[index] ?? false;
    return Column(children: [
      CheckboxListTile(
        value: isSelected,
        activeColor: Colors.orange,
        checkColor: Colors.black,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        dense: true,
        tileColor: isSelected ? Colors.orange.withOpacity(0.05) : null,
        title: Text(item['label'] ?? item['id'], style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontSize: 13, fontWeight: FontWeight.w500)),
        subtitle: Text("${item['value']} ${item['unit'] ?? ''}", style: TextStyle(color: isSelected ? Colors.orange : Colors.white24, fontSize: 12, fontFamily: 'Courier')),
        onChanged: (val) => setState(() => _selectedExtras[index] = val!),
      ),
      const Divider(height: 1, color: Colors.white10, indent: 16, endIndent: 16),
    ]);
  }

  // --- UPDATED SAVE LOGIC ---
  Future<void> _saveData() async {
    try {
      final timestamp = DateTime.now();
      
      // 1. Core Metrics (Loop through and save one by one)
      for (var item in coreMetrics) {
        String id = item['id'];
        var val = item['value'];
        
        dynamic cleanVal = val;
        
        // Handle parsing
        if (val is String && num.tryParse(val) != null) {
           cleanVal = num.parse(val);
        }
        
        // Call the service for EACH metric
        await HealthIngestionService().logHealthData(
          metricId: id,
          value: cleanVal,
          timestamp: timestamp,
        );
      }

      // 2. Extra Metrics (Optional: Save as generic 'lab_result' metric if you have one defined)
      // For now, we skip them unless you define a generic ID in HealthIDs.
      
      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        CyberSnackbar.show(context, "DATA SECURED", type: SnackbarType.success);
      }
    } catch (e) {
      CyberSnackbar.show(context, "SAVE FAILED: $e", type: SnackbarType.error);
    }
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  GridPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += 40) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}