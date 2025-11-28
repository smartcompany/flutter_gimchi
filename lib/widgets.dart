import 'package:flutter/material.dart';

class InfoItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const InfoItem({
    required this.label,
    required this.value,
    required this.color,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        TweenAnimationBuilder<double>(
          key: ValueKey(value), // value가 바뀔 때마다 새 위젯으로 인식
          tween: Tween<double>(begin: 1.5, end: 1.0),
          duration: Duration(milliseconds: 500),
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class CheckBoxItem extends StatelessWidget {
  final bool value;
  final String label;
  final Color color;
  final ValueChanged<bool?> onChanged;
  const CheckBoxItem({
    required this.value,
    required this.label,
    required this.color,
    required this.onChanged,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: color,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class StrategyCell extends StatelessWidget {
  final String text;
  final bool isHeader;
  const StrategyCell(this.text, {this.isHeader = false, super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: 15,
        ),
      ),
    );
  }
}

class HistoryRow extends StatelessWidget {
  final String label;
  final dynamic value;
  const HistoryRow({required this.label, required this.value, super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: Colors.deepPurple,
            ),
          ),
          Text(value?.toString() ?? '-', style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class BlinkingMarker extends StatefulWidget {
  final ImageProvider image;
  final double size;

  const BlinkingMarker({required this.image, this.size = 24.0, super.key});

  @override
  State<BlinkingMarker> createState() => _BlinkingMarkerState();
}

class _BlinkingMarkerState extends State<BlinkingMarker>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // 크기 애니메이션 (왕복)
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 2).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    // 광택 애니메이션 (반복)
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleController, _shimmerController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              children: [
                Image(image: widget.image),
                // 광택 효과
                Positioned.fill(
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(0.8),
                          Colors.white.withOpacity(0.0),
                        ],
                        stops: [
                          _shimmerController.value - 0.2,
                          _shimmerController.value,
                          _shimmerController.value + 0.2,
                        ],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.srcATop,
                    child: Image(image: widget.image),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
