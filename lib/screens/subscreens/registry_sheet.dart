import 'package:HealthGuard/models/health_metric_def.dart';
import 'package:HealthGuard/services/health_registry.dart';
import 'package:HealthGuard/widgets/components.dart';
import 'package:flutter/material.dart';

class RegistrySheet extends StatefulWidget {
  const RegistrySheet({super.key});

  @override
  State<RegistrySheet> createState() => _RegistrySheetState();
}

class _RegistrySheetState extends State<RegistrySheet> {
  String _query = "";
  final TextEditingController _searchController = TextEditingController();

  // Define Category Order
  final List<MetricCategory> _categoryOrder = [
    MetricCategory.vital,
    MetricCategory.activity,
    MetricCategory.nutrition,
    MetricCategory.environment,
    MetricCategory.lab,
    MetricCategory.other,
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          padding: EdgeInsets.only(
            top: 20, 
            left: 24, 
            right: 24, 
            bottom: MediaQuery.of(context).viewInsets.bottom 
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF121212), // Matching Analytics Tab Black
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Colors.white10, width: 1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- DRAG HANDLE ---
              Center(
                child: Container(
                  width: 40, height: 4, 
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              
              // --- HEADER ---
              const Text(
                "Select Metric", 
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 16),

              // --- SEARCH BAR ---
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                cursorColor: AppColors.neonBlue,
                decoration: InputDecoration(
                  hintText: "Search metrics...",
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                  suffixIcon: _query.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54, size: 18), 
                        onPressed: () { 
                          _searchController.clear(); 
                          setState(() => _query = ""); 
                        }
                      ) 
                    : null,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.neonBlue, width: 1)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                ),
                onChanged: (val) => setState(() => _query = val),
              ),
              const SizedBox(height: 24),

              // --- GRID CONTENT ---
              Expanded(
                child: _query.isEmpty 
                  ? _buildCategorizedGrid(scrollController) 
                  : _buildSearchResultsGrid(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- VIEW 1: SEARCH RESULTS ---
  Widget _buildSearchResultsGrid(ScrollController controller) {
    final results = HealthRegistry.search(_query);

    if (results.isEmpty) {
      return Center(
        child: Text("No metrics found.", style: TextStyle(color: Colors.white.withOpacity(0.3))),
      );
    }

    return SingleChildScrollView(
      controller: controller,
      physics: const BouncingScrollPhysics(),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: results.map((metric) => _buildGridItem(metric)).toList(),
      ),
    );
  }

  // --- VIEW 2: CATEGORIZED GRID ---
  Widget _buildCategorizedGrid(ScrollController controller) {
    List<Widget> listWidgets = [];
    final allMetrics = HealthRegistry.search(""); // Get all

    for (var category in _categoryOrder) {
      final sectionMetrics = allMetrics.where((m) => m.category == category).toList();
      
      if (sectionMetrics.isNotEmpty) {
        // 1. Header
        listWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 12),
            child: Text(
              _getCategoryLabel(category),
              style: const TextStyle(
                color: AppColors.textGrey, 
                fontSize: 11, 
                fontWeight: FontWeight.bold, 
                letterSpacing: 1.5
              ),
            ),
          )
        );

        // 2. Grid (Wrap)
        listWidgets.add(
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: sectionMetrics.map((metric) => _buildGridItem(metric)).toList(),
          )
        );
        
        // Spacer
        listWidgets.add(const SizedBox(height: 16));
      }
    }

    // Bottom padding
    listWidgets.add(const SizedBox(height: 40));

    return ListView(
      controller: controller,
      physics: const BouncingScrollPhysics(),
      children: listWidgets,
    );
  }

  // --- REUSABLE GRID TILE (Matches Analytics Tab Style) ---
  Widget _buildGridItem(HealthMetricDef metric) {
    // Calculate width for 2 items per row with padding
    // Screen Width - (Left Pad 24 + Right Pad 24 + Spacing 12) / 2
    final double itemWidth = (MediaQuery.of(context).size.width - 48 - 12) / 2;

    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.of(context).pop(metric);
      },
      child: Container(
        width: itemWidth,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03), 
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: metric.color.withOpacity(0.1), 
                shape: BoxShape.circle
              ),
              child: Icon(metric.icon, size: 16, color: metric.color),
            ),
            const SizedBox(width: 10),
            
            // Text Info
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.label, 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textGrey, 
                      fontSize: 12, 
                      fontWeight: FontWeight.w500
                    )
                  ),
                  const SizedBox(height: 2),
                  Text(
                    metric.unit, 
                    maxLines: 1, 
                    style: TextStyle(
                      color: metric.color.withOpacity(0.8), 
                      fontSize: 11, 
                      fontWeight: FontWeight.bold
                    )
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryLabel(MetricCategory cat) {
    switch (cat) {
      case MetricCategory.vital: return "VITALS";
      case MetricCategory.activity: return "ACTIVITY & BODY";
      case MetricCategory.nutrition: return "NUTRITION";
      case MetricCategory.environment: return "ENVIRONMENT";
      case MetricCategory.lab: return "LABS & CLINICAL";
      case MetricCategory.other: return "SUBJECTIVE";
      default: return "OTHER";
    }
  }
}