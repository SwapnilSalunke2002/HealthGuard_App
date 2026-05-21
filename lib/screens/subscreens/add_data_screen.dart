import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/health_ids.dart';
import '../../data/subjective_ids.dart'; // <--- NEW IMPORT
import '../../models/health_metric_def.dart';
import '../../services/health_ingestion_service.dart';
import '../../widgets/components.dart';
import '../../widgets/cyber_snackbar.dart';

class AddDataSheet extends StatefulWidget {
  final HealthMetricDef metric;

  const AddDataSheet({super.key, required this.metric});

  @override
  State<AddDataSheet> createState() => _AddDataSheetState();
}

class _AddDataSheetState extends State<AddDataSheet> {
  final TextEditingController _mainController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isLoading = false;
  
  // Subjective State
  double _sliderValue = 5.0; 
  int _moodValue = 3;        

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  Future<void> _saveData() async {
    setState(() => _isLoading = true);
    
    try {
      final timestamp = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        _selectedTime.hour, _selectedTime.minute
      );

      dynamic finalValue;

      // 1. Mood Check
      if (widget.metric.id == SubjectiveID.mood) {
        finalValue = _moodValue;
      }
      // 2. Slider Check
      else if ([SubjectiveID.stress, SubjectiveID.energy, SubjectiveID.pain, SubjectiveID.focus].contains(widget.metric.id)) {
        finalValue = _sliderValue.toInt();
      }
      // 3. Text Input (BP, HR, etc.)
      else {
        String text = _mainController.text.trim();
        if (text.isEmpty) throw "Enter a value.";
        finalValue = num.tryParse(text) ?? text; 
      }

      await HealthIngestionService().logHealthData(
        metricId: widget.metric.id,
        value: finalValue,
        timestamp: timestamp,
      );

      if (mounted) {
        Navigator.pop(context, true); 
        CyberSnackbar.show(context, "ENTRY LOGGED", type: SnackbarType.success);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      CyberSnackbar.show(context, e.toString(), type: SnackbarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.white10, width: 1)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),

              // --- HEADER ---
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: widget.metric.color.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(widget.metric.icon, color: widget.metric.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.metric.label.toUpperCase(), 
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1)
                    ),
                  ),
                  GestureDetector(
                    onTap: _pickDateTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        children: [
                          Text(DateFormat('MMM dd, HH:mm').format(_selectedDate), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(width: 6),
                          const Icon(Icons.edit_calendar, color: Colors.white38, size: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),

              _buildInputSection(),

              const SizedBox(height: 32),

              // --- SAVE BUTTON ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.metric.color,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Text("SAVE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- INPUT BUILDER ---
  Widget _buildInputSection() {
    // 1. MOOD (Emoji)
    if (widget.metric.id == SubjectiveID.mood) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildEmojiBtn(1, "Awful", Icons.sentiment_very_dissatisfied),
              _buildEmojiBtn(2, "Bad", Icons.sentiment_dissatisfied),
              _buildEmojiBtn(3, "Okay", Icons.sentiment_neutral),
              _buildEmojiBtn(4, "Good", Icons.sentiment_satisfied),
              _buildEmojiBtn(5, "Great", Icons.sentiment_very_satisfied),
            ],
          ),
          const SizedBox(height: 16),
          Text("Feeling: ${_getMoodLabel(_moodValue)}", style: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1)),
        ],
      );
    }

    // 2. SLIDER (Stress/Energy/Pain)
    if ([SubjectiveID.stress, SubjectiveID.energy, SubjectiveID.pain, SubjectiveID.focus].contains(widget.metric.id)) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Low", style: TextStyle(color: Colors.white30, fontSize: 12)),
              Text("${_sliderValue.toInt()} / 10", style: TextStyle(color: widget.metric.color, fontSize: 24, fontWeight: FontWeight.bold)),
              Text("High", style: TextStyle(color: Colors.white30, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: widget.metric.color,
              inactiveTrackColor: Colors.white10,
              thumbColor: Colors.white,
              overlayColor: widget.metric.color.withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: _sliderValue,
              min: 1,
              max: 10,
              divisions: 9,
              label: _sliderValue.toInt().toString(),
              onChanged: (val) => setState(() => _sliderValue = val),
            ),
          ),
        ],
      );
    }
    
    // 3. TEXT INPUT (Default)
    return _buildTextField(
      controller: _mainController, 
      label: "VALUE", 
      suffix: widget.metric.unit,
      isTextType: widget.metric.id == HealthID.bloodPressure
    );
  }

  // ... (Helpers: _buildEmojiBtn, _getMoodLabel, _buildTextField, _pickDateTime are same as before)
  Widget _buildEmojiBtn(int value, String label, IconData icon) {
    bool isSelected = _moodValue == value;
    Color color = isSelected ? widget.metric.color : Colors.white24;
    double scale = isSelected ? 1.2 : 1.0;

    return GestureDetector(
      onTap: () => setState(() => _moodValue = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(scale),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  String _getMoodLabel(int val) {
    switch (val) {
      case 1: return "Terrible";
      case 2: return "Bad";
      case 3: return "Okay";
      case 4: return "Good";
      case 5: return "Amazing";
      default: return "";
    }
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required String suffix, bool isTextType = false}) {
    return TextField(
      controller: controller,
      autofocus: true, 
      keyboardType: isTextType ? TextInputType.datetime : const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
      cursorColor: widget.metric.color,
      decoration: InputDecoration(
        labelText: isTextType ? "$label (e.g. 120/80)" : label,
        labelStyle: TextStyle(color: widget.metric.color.withOpacity(0.5), fontSize: 11, letterSpacing: 1),
        suffixText: suffix,
        suffixStyle: const TextStyle(color: Colors.white30, fontSize: 14),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.metric.color, width: 2)),
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context, 
      initialDate: _selectedDate, 
      firstDate: DateTime(2000), 
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.neonBlue)), child: child!)
    );
    if (d != null) {
      final t = await showTimePicker(
        context: context, 
        initialTime: _selectedTime,
        builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.neonBlue)), child: child!)
      );
      if (t != null) setState(() { _selectedDate = d; _selectedTime = t; });
    }
  }
}