import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:math' as math;

// --- 1. THEME COLORS ---
class AppColors {
  static const Color bgDark = Color(0xff040B0F);
  static const Color textWhite = Color(0xFFF1F5F9);
  static const Color textGrey = Color(0xFF94A3B8);

  static const Color signalRed = Color(0xFFFF4D4D);
  static const Color signalYellow = Color(0xFFFFD166);
  static const Color signalGreen = Color(0xFF06D6A0);
  static const Color neonBlue = Color(0xFF00E5FF);
  static const Color neonViolet = Color(0xFF7C3AED);
}

// --- 2. BEAUTY GAUGE WIDGET ---
class BeautySignalGauge extends StatelessWidget {
  final double score;
  const BeautySignalGauge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: const Size(220, 220),
          painter: _BeautyGaugePainter(percentage: score / 100),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            GestureDetector(child: Icon(Icons.shield_rounded, color: _getStatusColor(score), size: 28)),
            
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.white, Color(0xFFE0F7FA)], 
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ).createShader(bounds),
              child: Text(
                "${score.toInt()}",
                style: const TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.w200,
                  color: Colors.white,
                  height: 1.0,
                  letterSpacing: -2.0,
                ),
              ),
            ),
            
            Text(
              _getStatusText(score),
              style: TextStyle(
                fontSize: 12,
                color: _getStatusColor(score),
                letterSpacing: 4.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        )
      ],
    );
  }

  Color _getStatusColor(double score) {
    if (score > 80) return AppColors.signalGreen;
    if (score > 50) return AppColors.signalYellow;
    return AppColors.signalRed;
  }

  String _getStatusText(double score) {
    if (score > 80) return "OPTIMAL";
    if (score > 50) return "WARNING";
    return "CRITICAL";
  }
}

// --- 3. GAUGE PAINTER ---
class _BeautyGaugePainter extends CustomPainter {
  final double percentage;
  _BeautyGaugePainter({required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.5;

    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.8,
      math.pi * 1.4,
      false,
      trackPaint,
    );

    final activePaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.signalRed, AppColors.signalYellow, AppColors.signalGreen],
        stops: [0.0, 0.4, 1.0], 
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4); 

    final sweepAngle = math.pi * 1.4 * percentage;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.8,
      sweepAngle,
      false,
      activePaint,
    );

    final endAngle = (math.pi * 0.8) + sweepAngle;
    final knobX = center.dx + radius * math.cos(endAngle);
    final knobY = center.dy + radius * math.sin(endAngle);

    canvas.drawCircle(Offset(knobX, knobY), 5, Paint()..color = AppColors.textWhite);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- 4. METRIC PILL WIDGET ---
class MetricPill extends StatelessWidget {
  final String label, value, unit;
  final IconData icon;
  final Color iconColor;

  const MetricPill({
    super.key, 
    required this.label, 
    required this.value, 
    required this.unit, 
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value, style: const TextStyle(color: AppColors.textWhite, fontSize: 22, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    Text(unit, style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label, 
                style: const TextStyle(color: AppColors.textGrey, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          )
        ],
      ),
    );
  }
}

// --- 5. COMPACT TILE WIDGET ---
class EnvCompactTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color accentColor;
  final Color? valueColor; // <--- ADD THIS OPTIONAL PARAMETER

  const EnvCompactTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.valueColor, // <--- ADD THIS
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value, 
                      style: TextStyle(
                        // USE valueColor IF PROVIDED, ELSE DEFAULT TO WHITE
                        color: valueColor ?? AppColors.textWhite, 
                        fontSize: 16, 
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label, 
                      style: const TextStyle(color: AppColors.textGrey, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 6. BACKGROUND GRID PAINTER ---
class GridPainter extends CustomPainter {
  final Color color;
  GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1.0;
    const double gridSize = 40.0;
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



// --- 7. REUSABLE ANIMATED BACKGROUND ---
class GlobalAnimatedBackground extends StatefulWidget {
  const GlobalAnimatedBackground({super.key});

  @override
  State<GlobalAnimatedBackground> createState() => _GlobalAnimatedBackgroundState();
}

class _GlobalAnimatedBackgroundState extends State<GlobalAnimatedBackground> with SingleTickerProviderStateMixin {
  late AnimationController _auroraController;

  @override
  void initState() {
    super.initState();
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _auroraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _auroraController,
          builder: (context, child) {
            return Positioned(
              top: -200 + (_auroraController.value * 30),
              right: -200,
              child: Container(
                height: 600,
                width: 600,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.neonBlue.withOpacity(0.08), 
                      AppColors.bgDark.withOpacity(0.0),
                    ],
                    radius: 0.6,
                  ),
                ),
              ),
            );
          },
        ),
        AnimatedBuilder(
          animation: _auroraController,
          builder: (context, child) {
            return Positioned(
              bottom: -200 + (_auroraController.value * 50),
              left: -100,
              child: Container(
                height: 500,
                width: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.neonViolet.withOpacity(0.06), 
                      AppColors.bgDark.withOpacity(0.0),
                    ],
                    radius: 0.6,
                  ),
                ),
              ),
            );
          },
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: GridPainter(color: Colors.white.withOpacity(0.02)),
          ),
        ),
      ],
    );
  }
}