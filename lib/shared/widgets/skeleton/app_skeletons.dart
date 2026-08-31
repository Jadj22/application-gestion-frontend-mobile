import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'skeleton.dart';

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonText(width: 220, height: 22),
          const SizedBox(height: 8),
          const SkeletonText(width: 280, height: 12),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 600 ? 3 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: cols == 2 ? 1.35 : 1.5,
                children: List.generate(
                  6,
                  (_) => const SkeletonBox(
                    height: double.infinity,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const SkeletonText(width: 160, height: 18),
          const SizedBox(height: 12),
          SkeletonCard(
            radius: 12,
            padding: EdgeInsets.zero,
            child: Column(
              children: List.generate(
                4,
                (i) => Column(
                  children: [
                    if (i > 0)
                      const Divider(
                        height: 1,
                        color: AppColors.dashOutlineVariant,
                      ),
                    const SkeletonListItem(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SkeletonText(width: 180, height: 18),
          const SizedBox(height: 12),
          SkeletonCard(
            radius: 12,
            padding: EdgeInsets.zero,
            child: Column(
              children: List.generate(
                3,
                (i) => Column(
                  children: [
                    if (i > 0)
                      const Divider(
                        height: 1,
                        color: AppColors.dashOutlineVariant,
                      ),
                    const SkeletonListItem(leadingCircle: true, leadingSize: 36),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      child: Row(
        children: [
          SkeletonImage(width: 72, height: 72, radius: 12),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: 160, height: 15),
                SizedBox(height: 6),
                SkeletonText(width: 90, height: 10),
                SizedBox(height: 12),
                Row(
                  children: [
                    SkeletonText(width: 70, height: 12),
                    Spacer(),
                    SkeletonBox(
                      width: 72,
                      height: 22,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InventorySkeleton extends StatelessWidget {
  const InventorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => const ProductCardSkeleton(),
      ),
    );
  }
}

class UserCardSkeleton extends StatelessWidget {
  const UserCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: const Row(
        children: [
          SkeletonAvatar(size: 48),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: 140, height: 16),
                SizedBox(height: 6),
                SkeletonText(width: 180, height: 12),
                SizedBox(height: 10),
                Row(
                  children: [
                    SkeletonBox(
                      width: 86,
                      height: 24,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                    SizedBox(width: 8),
                    SkeletonBox(
                      width: 72,
                      height: 24,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MembersListSkeleton extends StatelessWidget {
  const MembersListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => const UserCardSkeleton(),
      ),
    );
  }
}

class ReservationCardSkeleton extends StatelessWidget {
  const ReservationCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonText(width: 180, height: 16),
          SizedBox(height: 10),
          SkeletonText(width: double.infinity, height: 12),
          SizedBox(height: 8),
          SkeletonText(width: 200, height: 12),
          SizedBox(height: 16),
          Row(
            children: [
              SkeletonBox(
                width: 88,
                height: 28,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              SizedBox(width: 8),
              SkeletonBox(
                width: 88,
                height: 28,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NotificationSkeleton extends StatelessWidget {
  const NotificationSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonListItem(leadingCircle: true, leadingSize: 36);
  }
}

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Skeleton(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            SkeletonAvatar(size: 88),
            SizedBox(height: 16),
            SkeletonText(width: 160, height: 18),
            SizedBox(height: 8),
            SkeletonText(width: 200, height: 12),
            SizedBox(height: 24),
            SkeletonButton(width: double.infinity, height: 48),
            SizedBox(height: 12),
            SkeletonButton(width: double.infinity, height: 48),
          ],
        ),
      ),
    );
  }
}

class DetailsSkeleton extends StatelessWidget {
  const DetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: const [
          SkeletonImage(width: double.infinity, height: 220, radius: 20),
          SizedBox(height: 20),
          SkeletonText(width: 220, height: 22),
          SizedBox(height: 8),
          SkeletonText(width: 140, height: 12),
          SizedBox(height: 24),
          SkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: 100, height: 12),
                SizedBox(height: 12),
                SkeletonText(width: double.infinity, height: 14),
                SizedBox(height: 8),
                SkeletonText(width: double.infinity, height: 14),
                SizedBox(height: 8),
                SkeletonText(width: 180, height: 14),
              ],
            ),
          ),
          SizedBox(height: 16),
          SkeletonCard(
            child: Column(
              children: [
                SkeletonListItem(),
                SkeletonListItem(),
                SkeletonListItem(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MaintenanceTaskSkeleton extends StatelessWidget {
  const MaintenanceTaskSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonCard(
      radius: 16,
      padding: const EdgeInsets.all(12),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(
                width: 44,
                height: 44,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              SizedBox(width: 10),
              SkeletonBox(
                width: 92,
                height: 22,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
            ],
          ),
          SizedBox(height: 12),
          SkeletonText(width: 180, height: 14),
          SizedBox(height: 6),
          SkeletonText(width: 120, height: 12),
        ],
      ),
    );
  }
}

class MaintenanceListSkeleton extends StatelessWidget {
  const MaintenanceListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => const MaintenanceTaskSkeleton(),
      ),
    );
  }
}

class FormOptionsSkeleton extends StatelessWidget {
  const FormOptionsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Skeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonText(width: 90, height: 11),
          SizedBox(height: 8),
          SkeletonBox(
            width: double.infinity,
            height: 54,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ],
      ),
    );
  }
}

class OnboardingTypesSkeleton extends StatelessWidget {
  const OnboardingTypesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: const [
          SkeletonText(width: 100, height: 11),
          SizedBox(height: 8),
          SkeletonText(width: 220, height: 22),
          SizedBox(height: 24),
          SkeletonCard(child: SizedBox(height: 72)),
          SizedBox(height: 12),
          SkeletonCard(child: SizedBox(height: 72)),
        ],
      ),
    );
  }
}

class ActionsPageSkeleton extends StatelessWidget {
  const ActionsPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          SkeletonCard(
            radius: 12,
            padding: EdgeInsets.zero,
            child: Column(
              children: List.generate(
                5,
                (i) => Column(
                  children: [
                    if (i > 0)
                      const Divider(
                        height: 1,
                        color: AppColors.dashOutlineVariant,
                      ),
                    const SkeletonListItem(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryPanelSkeleton extends StatelessWidget {
  const HistoryPanelSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Skeleton(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            SkeletonListItem(),
            SkeletonListItem(),
            SkeletonListItem(),
          ],
        ),
      ),
    );
  }
}
