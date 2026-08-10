import 'package:flutter/material.dart';

/// A shimmer placeholder grid shown while photos are loading.
class ShimmerGrid extends StatefulWidget {
  final int itemCount;
  final double aspectRatio;
  const ShimmerGrid({
    super.key,
    this.itemCount = 9,
    this.aspectRatio = 4 / 3,
  });

  @override
  State<ShimmerGrid> createState() => _ShimmerGridState();
}

class _ShimmerGridState extends State<ShimmerGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shimmer = _controller.value;
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: widget.aspectRatio,
          ),
          itemCount: widget.itemCount,
          itemBuilder: (context, index) {
            final brightness = 0.08 + 0.06 * ((shimmer + index * 0.15) % 1.0);
            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: brightness),
                borderRadius: BorderRadius.circular(6),
              ),
            );
          },
        );
      },
    );
  }
}
