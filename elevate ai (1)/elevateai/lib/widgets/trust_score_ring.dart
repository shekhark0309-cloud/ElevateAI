import 'package:flutter/material.dart';
import 'dart:math' as math;

class TrustScoreRing extends StatefulWidget {
  final double score;
  final String tier;
  final double size;

  const TrustScoreRing({
    super.key,
    required this.score,
    required this.tier,
    this.size = 150,
  });

  @override
  State<TrustScoreRing> createState() => _TrustScoreRingState();
}

class _TrustScoreRingState extends State<TrustScoreRing> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(begin: 0, end: widget.score).animate(
      CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(TrustScoreRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _animation = Tween<double>(begin: oldWidget.score, end: widget.score).animate(
        CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn),
      );
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getTierColor() {
    switch (widget.tier.toLowerCase()) {
      case 'platinum': return Colors.blueGrey;
      case 'gold': return Colors.amber;
      case 'silver': return Colors.grey;
      case 'bronze': return Colors.brown;
      default: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getTierColor();

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: CircularProgressIndicator(
                value: _animation.value / 100,
                strokeWidth: 12,
                backgroundColor: color.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _animation.value.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: widget.size * 0.22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  widget.tier,
                  style: TextStyle(
                    fontSize: widget.size * 0.1,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
