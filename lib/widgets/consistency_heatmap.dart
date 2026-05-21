import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import '../widgets/components.dart'; 

class ConsistencyHeatmap extends StatelessWidget {
  final List<DateTime> logDates;

  const ConsistencyHeatmap({super.key, required this.logDates});

  @override
  Widget build(BuildContext context) {
    Map<DateTime, int> dataset = {};
    for (var date in logDates) {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      dataset[normalizedDate] = (dataset[normalizedDate] ?? 0) + 1;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12), // Minimized padding
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER ROW (Tight) ---
          Padding(
            padding: const EdgeInsets.only(right: 10), // Padding for legend
            child: Row(
              children: [
                const Icon(Icons.grid_on_rounded, size: 12, color: AppColors.textGrey),
                const SizedBox(width: 6),
                const Text(
                  "DATA CONTINUITY", 
                  style: TextStyle(
                    color: AppColors.textGrey, 
                    fontSize: 10, 
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 1.2
                  )
                ),
                const Spacer(),
                _buildMicroLegend(),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // --- FULL WIDTH HEATMAP ---
          HeatMap(
            datasets: dataset,
            // 105 days = 15 weeks. This usually fills a standard phone width (360-400px)
            startDate: DateTime.now().subtract(const Duration(days: 105)), 
            endDate: DateTime.now(),
            
            // Sizing: Small squares, tight margins
            size: 13, 
            margin: const EdgeInsets.all(2), 
            fontSize: 9,
            
            colorMode: ColorMode.color, 
            showText: false, 
            scrollable: true, // Allows scrolling if screen is too narrow
            textColor: AppColors.textGrey,
            defaultColor: Colors.white.withOpacity(0.05),
            
            colorsets: {
              1: AppColors.signalGreen, 
              3: AppColors.neonBlue, 
            },
            onClick: (value) {},
          ),
        ],
      ),
    );
  }

  Widget _buildMicroLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(Colors.white.withOpacity(0.05)),
        const SizedBox(width: 3),
        _dot(AppColors.signalGreen),
        const SizedBox(width: 3),
        _dot(AppColors.neonBlue),
      ],
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 6, 
      height: 6, 
      decoration: BoxDecoration(
        color: color, 
        borderRadius: BorderRadius.circular(1.5)
      )
    );
  }
}