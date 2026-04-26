import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.4),
      highlightColor: Colors.white.withValues(alpha: 0.8),
      period: const Duration(milliseconds: 1500),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class HomeShimmer extends StatelessWidget {
  const HomeShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Carousel Shimmer
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ShimmerSkeleton(
              width: double.infinity,
              height: 480,
              borderRadius: 32,
            ),
          ),
          const SizedBox(height: 24),
          // Section Title Shimmer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ShimmerSkeleton(width: 120, height: 24),
          ),
          const SizedBox(height: 16),
          // Horizontal List Shimmer
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child:
                    ShimmerSkeleton(width: 140, height: 200, borderRadius: 12),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Another Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ShimmerSkeleton(width: 150, height: 24),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ShimmerSkeleton(
                width: double.infinity, height: 160, borderRadius: 20),
          ),
        ],
      ),
    );
  }
}

class WatchlistShimmer extends StatelessWidget {
  const WatchlistShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.60,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => ShimmerSkeleton(
        width: double.infinity,
        height: double.infinity,
        borderRadius: 20,
      ),
    );
  }
}

class SearchShimmer extends StatelessWidget {
  const SearchShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            ShimmerSkeleton(width: 60, height: 80, borderRadius: 8),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerSkeleton(width: double.infinity, height: 20),
                  const SizedBox(height: 8),
                  ShimmerSkeleton(width: 150, height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailShimmer extends StatelessWidget {
  const DetailShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerSkeleton(width: double.infinity, height: 400, borderRadius: 0),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerSkeleton(width: 250, height: 32),
                const SizedBox(height: 12),
                ShimmerSkeleton(width: 180, height: 20),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                        child: ShimmerSkeleton(
                            width: double.infinity,
                            height: 50,
                            borderRadius: 25)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: ShimmerSkeleton(
                            width: double.infinity,
                            height: 50,
                            borderRadius: 25)),
                  ],
                ),
                const SizedBox(height: 32),
                ShimmerSkeleton(width: 100, height: 24),
                const SizedBox(height: 12),
                ShimmerSkeleton(width: double.infinity, height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MagazineShimmer extends StatelessWidget {
  const MagazineShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const ShimmerSkeleton(width: 140, height: 24),
              const ShimmerSkeleton(width: 80, height: 16),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 4,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (_, __) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ShimmerSkeleton(width: 140, height: 200, borderRadius: 12),
            ),
          ),
        ),
      ],
    );
  }
}
