import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble; 
import 'package:intl/intl.dart';

// Project Imports
import '../../data/health_ids.dart';
import '../../data/subjective_ids.dart'; 
import '../../data/env_ids.dart';
import '../../models/health_metric_def.dart';
import '../../services/health_registry.dart';
import '../../services/health_retrieval_service.dart';
import '../subscreens/registry_sheet.dart';
import '../../widgets/cyber_snackbar.dart';
import '../../widgets/components.dart';

// Screens
import '../subscreens/cyber_analysis_screen.dart';
import '../subscreens/add_data_screen.dart'; 

class DataEntryTab extends StatefulWidget {
  const DataEntryTab({super.key});

  @override
  State<DataEntryTab> createState() => _DataEntryTabState();
}

class _DataEntryTabState extends State<DataEntryTab> {
  
  // --- DATA STATE ---
  final HealthRetrievalService _retrievalService = HealthRetrievalService();
  final Map<String, dynamic> _metricsState = {}; 
  bool _isLoading = true;
  StreamSubscription? _dailySummarySub;

  // --- MULTI-DEVICE STATE ---
  final List<ble.BluetoothDevice> _connectedDevices = [];
  
  @override
  void initState() {
    super.initState();
    _setupRealtimeListener(); 
    _loadHistoricalVitals();  
  }

  @override
  void dispose() {
    _dailySummarySub?.cancel(); 
    _stopScan();
    super.dispose();
  }

  // ==========================================================
  // 1. DATA ENGINE 
  // ==========================================================

  void _setupRealtimeListener() {
    // We now use the Supabase-powered retrieval service instead of raw Firestore!
    _dailySummarySub = _retrievalService.streamTodaySummary().listen((data) {
      if (mounted) {
        setState(() {
          _metricsState.addAll(data);
          _isLoading = false;
        });
      }
    }, onError: (error) {
      print("❌ [DataEntry] Realtime Sync Error: $error");
      if (mounted) setState(() => _isLoading = false);
    });
  }

  Future<void> _loadHistoricalVitals() async {
    try {
      final now = DateTime.now();
      if (!_metricsState.containsKey(HealthID.weight)) {
        final data = await _retrievalService.fetchHistory(metricId: HealthID.weight, start: now.subtract(const Duration(days: 30)), end: now);
        if (data.isNotEmpty && mounted) setState(() => _metricsState[HealthID.weight] = data.last.value);
      }
    } catch (_) {}
  }

  // ==========================================================
  // 2. UI BUILDER
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    // --- SECTION 1: DAILY / HIGH FREQUENCY ---
    final List<String> quickLogIds = [
      SubjectiveID.mood,
      SubjectiveID.energy,
      HealthID.heartRate,
      HealthID.steps,
      HealthID.water,
      HealthID.sleep
    ];

    // --- SECTION 2: CLINICAL / LOW FREQUENCY ---
    final List<String> clinicalIds = [
      HealthID.bloodPressure,
      HealthID.glucose,
      HealthID.bodyTemp,
      HealthID.weight,
      EnvID.noiseLevel,
      EnvID.airQuality,
    ];

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          const GlobalAnimatedBackground(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // HEADER & DEVICES
                  _buildHeaderAndDevices(),
                  const SizedBox(height: 30),

                  // HERO SCANNER
                  _buildUniversalScanner(),
                  const SizedBox(height: 30),

                  // --- SECTION 1: QUICK LOG & VIEW ---
                  // (Renamed back to your requested title)
                  _buildSectionHeader("QUICK LOG & VIEW", isLoading: _isLoading),
                  const SizedBox(height: 16),
                  MetricGridSection(
                    metricIds: quickLogIds, 
                    metricsState: _metricsState, 
                    onTap: (metric) => _openAddDataScreen(metric),
                    showAddButton: true, // "Add" button lives here
                    onAddTap: _showRegistrySelector,
                  ),

                  const SizedBox(height: 30),

                  // --- SECTION 2: CLINICAL & ENV ---
                  _buildSectionHeader("CLINICAL & ENV"),
                  const SizedBox(height: 16),
                  MetricGridSection(
                    metricIds: clinicalIds, 
                    metricsState: _metricsState, 
                    onTap: (metric) => _openAddDataScreen(metric),
                    showAddButton: false, 
                  ),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 3. UI COMPONENTS
  // ==========================================================

  Widget _buildHeaderAndDevices() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("SYSTEM UPLINK", style: TextStyle(color: AppColors.textGrey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            Container(width: 6, height: 6, decoration: BoxDecoration(color: _connectedDevices.isNotEmpty ? AppColors.neonBlue : AppColors.signalGreen, shape: BoxShape.circle, boxShadow: [BoxShadow(color: (_connectedDevices.isNotEmpty ? AppColors.neonBlue : AppColors.signalGreen).withOpacity(0.5), blurRadius: 6)])),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36, 
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none, 
            children: [
              _buildStatusPill("GPS", "Locked", AppColors.signalGreen, Icons.gps_fixed),
              const SizedBox(width: 8),
              _buildStatusPill("Cloud", "Sync", AppColors.signalGreen, Icons.cloud_done_rounded),
              const SizedBox(width: 8),
              ..._connectedDevices.map((device) => Padding(padding: const EdgeInsets.only(right: 8.0), child: _buildDeviceChip(device))),
              GestureDetector(
                onTap: _showDeviceConnector,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.neonBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.neonBlue.withOpacity(0.3))),
                  child: const Icon(Icons.add, color: AppColors.neonBlue, size: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUniversalScanner() {
    return GestureDetector(
      onTap: _showImportOptions,
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.neonBlue.withOpacity(0.2))),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, color: AppColors.neonBlue.withOpacity(0.9), size: 32),
            const SizedBox(height: 12),
            const Text("Universal Scanner", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            const Text("Scan Reports • Food • Devices", style: TextStyle(color: AppColors.textGrey, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool isLoading = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: AppColors.textGrey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        if (isLoading) const SizedBox(height: 12, width: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textGrey))
      ],
    );
  }

  // ==========================================================
  // 4. ACTION HANDLERS
  // ==========================================================

  void _openAddDataScreen(HealthMetricDef metric) async {
    // 1. Await the result of the bottom sheet
    final bool? didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddDataSheet(metric: metric), 
    );

    // 2. If data was saved, force a refresh of the historical metrics
    if (didSave == true && mounted) {
      // Force fetch the newly saved data
      final now = DateTime.now();
      final data = await _retrievalService.fetchHistory(
        metricId: metric.id, 
        start: now.subtract(const Duration(days: 30)), 
        end: now
      );
      
      if (data.isNotEmpty) {
        setState(() {
          _metricsState[metric.id] = data.last.value;
        });
      }
    }
  }

  Future<void> _showRegistrySelector() async {
    final HealthMetricDef? metric = await showModalBottomSheet<HealthMetricDef>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RegistrySheet(), 
    );

    if (metric != null && mounted) {
      _openAddDataScreen(metric);
    }
  }

  // --- BLUETOOTH & FILE LOGIC ---
  Future<void> _connectAndFetch(ble.BluetoothDevice device) async {
    _stopScan(); Navigator.pop(context); 
    if (_connectedDevices.any((d) => d.remoteId == device.remoteId)) { CyberSnackbar.show(context, "Already active!", type: SnackbarType.info); return; }
    showModalBottomSheet(context: context, isDismissible: false, backgroundColor: Colors.transparent, builder: (context) => _buildExtractionTerminal(device.platformName));
    try {
      await device.connect(timeout: const Duration(seconds: 5), license: ble.License.free);
      await Future.delayed(const Duration(seconds: 2)); 
      if (!mounted) return;
      setState(() { _connectedDevices.add(device); _metricsState[HealthID.heartRate] = 78; });
      Navigator.pop(context); 
      CyberSnackbar.show(context, "LINKED", type: SnackbarType.success);
    } catch (e) {
      if (mounted) { Navigator.pop(context); CyberSnackbar.show(context, "Failed: $e", type: SnackbarType.error); }
    }
  }

  Future<void> _disconnectDevice(ble.BluetoothDevice device) async {
    try { await device.disconnect(); } catch (_) {}
    if (mounted) setState(() => _connectedDevices.removeWhere((d) => d.remoteId == device.remoteId));
  }
  
  Future<void> _startScan() async {
    if (Platform.isAndroid) {
      // Must request all three simultaneously on modern Android
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan, 
        Permission.bluetoothConnect, 
        Permission.location // Crucial for BLE
      ].request();
      
      if (statuses[Permission.bluetoothScan]!.isDenied || statuses[Permission.location]!.isDenied) {
        CyberSnackbar.show(context, "Bluetooth & Location required to scan", type: SnackbarType.warning);
        return;
      }
    }
    try { 
      await ble.FlutterBluePlus.stopScan(); 
      await ble.FlutterBluePlus.startScan(timeout: const Duration(seconds: 15), androidUsesFineLocation: true); 
    } catch (_) {}
  }

  void _stopScan() { try { ble.FlutterBluePlus.stopScan(); } catch (_) {} }
  void _showDeviceConnector() { _startScan(); showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (context) => _buildScannerSheet()).whenComplete(() => _stopScan()); }
  void _showImportOptions() { showModalBottomSheet(context: context, backgroundColor: const Color(0xFF121212), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) => _buildImportSheet(context)); }

  // --- SMALLER WIDGETS ---
  Widget _buildScannerSheet() { return Container(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 24, left: 24, right: 24), height: MediaQuery.of(context).size.height * 0.6, decoration: const BoxDecoration(color: Color(0xFF121212), borderRadius: BorderRadius.vertical(top: Radius.circular(24)), border: Border(top: BorderSide(color: Colors.white10, width: 1))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("NEARBY SOURCES", style: TextStyle(color: AppColors.textGrey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)), SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonBlue))]), const SizedBox(height: 20), Expanded(child: StreamBuilder<List<ble.ScanResult>>(stream: ble.FlutterBluePlus.scanResults, initialData: const [], builder: (context, snapshot) { final displayList = (snapshot.data ?? []).where((r) => r.device.platformName.isNotEmpty).toList(); if (displayList.isEmpty) return const Center(child: Text("Searching...", style: TextStyle(color: Colors.white38))); return ListView.separated(itemCount: displayList.length, separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1), itemBuilder: (context, index) { final result = displayList[index]; final isConnected = _connectedDevices.any((d) => d.remoteId == result.device.remoteId); return ListTile(leading: Icon(isConnected ? Icons.link : Icons.bluetooth, color: isConnected ? AppColors.neonBlue : Colors.white, size: 20), title: Text(result.device.platformName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)), trailing: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonBlue.withOpacity(0.1), foregroundColor: AppColors.neonBlue, minimumSize: const Size(0, 32)), onPressed: isConnected ? null : () => _connectAndFetch(result.device), child: Text(isConnected ? "Linked" : "Connect", style: const TextStyle(fontSize: 12)))); }); }))])); }
  Widget _buildExtractionTerminal(String deviceName) { return Container(padding: const EdgeInsets.all(30), decoration: const BoxDecoration(color: Color(0xFF0F0F0F), borderRadius: BorderRadius.vertical(top: Radius.circular(30)), border: Border(top: BorderSide(color: AppColors.neonBlue, width: 2))), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("ESTABLISHING DATA LINK...", style: TextStyle(color: AppColors.neonBlue, fontWeight: FontWeight.bold, letterSpacing: 1.5)), const SizedBox(height: 20), const LinearProgressIndicator(color: AppColors.neonBlue, backgroundColor: Colors.white10)])); }
  Widget _buildStatusPill(String label, String status, Color color, IconData icon) { return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))), child: Row(children: [Icon(icon, color: AppColors.textGrey, size: 12), const SizedBox(width: 6), Text("$label: ", style: const TextStyle(color: AppColors.textGrey, fontSize: 11)), Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600))])); }
  Widget _buildDeviceChip(ble.BluetoothDevice device) { return GestureDetector(onTap: () => _showDisconnectDialog(device), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: AppColors.neonBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.neonBlue.withOpacity(0.3))), child: Row(children: [const Icon(Icons.link, color: AppColors.neonBlue, size: 14), const SizedBox(width: 6), Text(device.platformName.length > 10 ? "${device.platformName.substring(0, 8)}..." : device.platformName, style: const TextStyle(color: AppColors.neonBlue, fontSize: 11, fontWeight: FontWeight.bold))]))); }
  void _showDisconnectDialog(ble.BluetoothDevice device) { showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: const Color(0xFF121212), title: Text("Disconnect ${device.platformName}?", style: const TextStyle(color: Colors.white, fontSize: 16)), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))), TextButton(onPressed: (){ Navigator.pop(ctx); _disconnectDevice(device); }, child: const Text("Disconnect", style: TextStyle(color: AppColors.signalRed)))])); }
  Widget _buildImportSheet(BuildContext context) { return Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text("SELECT INPUT SOURCE", style: TextStyle(color: AppColors.textGrey, letterSpacing: 1.5, fontSize: 10, fontWeight: FontWeight.bold)), const SizedBox(height: 20), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_buildSourceBtn(Icons.camera_alt_rounded, "Camera", () => _pickImage(ImageSource.camera)), _buildSourceBtn(Icons.photo_library_rounded, "Gallery", () => _pickImage(ImageSource.gallery)), _buildSourceBtn(Icons.folder_open_rounded, "Files", _pickDocument)]), const SizedBox(height: 20)])); }
  Widget _buildSourceBtn(IconData icon, String label, VoidCallback onTap) { return GestureDetector(onTap: () { Navigator.pop(context); onTap(); }, child: Column(children: [Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.1))), child: Icon(icon, color: Colors.white, size: 24)), const SizedBox(height: 8), Text(label, style: const TextStyle(color: AppColors.textGrey, fontSize: 12))])); }
  Future<void> _pickImage(ImageSource source) async { final ImagePicker picker = ImagePicker(); try { final XFile? image = await picker.pickImage(source: source); if (image != null && mounted) _navigateToAnalysis(File(image.path), 'image'); } catch (e) { debugPrint(e.toString()); } }
  Future<void> _pickDocument() async { try { FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx']); if (result != null && mounted) _navigateToAnalysis(File(result.files.single.path!), 'doc'); } catch (e) { debugPrint(e.toString()); } }
  void _navigateToAnalysis(File file, String type) { Navigator.push(context, MaterialPageRoute(builder: (context) => CyberAnalysisScreen(file: file, fileType: type))); }
}

// ==========================================================
// MODULAR COMPONENT: METRIC GRID SECTION
// ==========================================================

class MetricGridSection extends StatelessWidget {
  final List<String> metricIds;
  final Map<String, dynamic> metricsState;
  final Function(HealthMetricDef) onTap;
  final bool showAddButton;
  final VoidCallback? onAddTap;

  const MetricGridSection({
    super.key,
    required this.metricIds,
    required this.metricsState,
    required this.onTap,
    this.showAddButton = false,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2,
      ),
      itemCount: metricIds.length + (showAddButton ? 1 : 0),
      itemBuilder: (context, index) {
        if (showAddButton && index == 0) {
          return _buildAddTile();
        }
        final adjustedIndex = showAddButton ? index - 1 : index;
        return _buildMetricTile(metricIds[adjustedIndex]);
      },
    );
  }

  Widget _buildAddTile() { 
    return GestureDetector(
      onTap: onAddTap, 
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: AppColors.neonBlue.withOpacity(0.5), width: 1),
          color: AppColors.neonBlue.withOpacity(0.05),
        ), 
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: const [
            Icon(Icons.add, color: AppColors.neonBlue, size: 18), 
            SizedBox(width: 8), 
            Text("ADD", style: TextStyle(color: AppColors.neonBlue, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1))
          ],
        ),
      ),
    ); 
  }

  Widget _buildMetricTile(String metricId) {
    final def = HealthRegistry.get(metricId);
    if (def == null) return const SizedBox(); 

    dynamic rawValue = metricsState[metricId];
    String displayValue = _formatValue(metricId, rawValue);
    
    return GestureDetector(
      onTap: () => onTap(def),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: def.color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(def.icon, color: def.color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    def.label, 
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "$displayValue ${def.unit}", 
                      style: TextStyle(color: AppColors.textGrey.withOpacity(0.9), fontSize: 11),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  String _formatValue(String metricId, dynamic value) {
    if (value == null) return "--";
    if (metricId == SubjectiveID.mood && value is num) {
      switch(value.toInt()) {
        case 1: return "Awful";
        case 2: return "Bad";
        case 3: return "Okay";
        case 4: return "Good";
        case 5: return "Great";
        default: return "$value";
      }
    }
    if (metricId == HealthID.steps && value is num) {
      return NumberFormat('#,###').format(value);
    }
    return "$value";
  }
}