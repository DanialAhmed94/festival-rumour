import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import 'leaderboard_view_model.dart';

class LeaderboardView extends BaseView<LeaderboardViewModel> {
  const LeaderboardView({super.key});

  @override
  LeaderboardViewModel createViewModel() => LeaderboardViewModel();
  @override
  Widget buildView(BuildContext context, LeaderboardViewModel viewModel) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          /// ✅ Pink AppBar (Same as HomeView)
          SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              color: const Color(0xFFFC2E95),
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingM,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const ResponsiveTextWidget(
                    AppStrings.leaderBoard,
                    textType: TextType.title,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  const SizedBox(width: 40), // keeps title centered
                ],
              ),
            ),
          ),

          /// Body
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.paddingM,
              ),
              child: Column(
                children: [
                  const SizedBox(height: AppDimensions.paddingS),

                  /// Title (Black Text)
                  const ResponsiveTextWidget(
                    AppStrings.lunaFest2025,
                    textType: TextType.heading,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),

                  const SizedBox(height: AppDimensions.paddingL),

                  /// Podium
                  if (viewModel.leaders.length >= 3)
                    LeaderboardWidgets.buildPodiumSection(
                      first: viewModel.leaders[0],
                      second: viewModel.leaders[1],
                      third: viewModel.leaders[2],
                    ),

                  const SizedBox(height: AppDimensions.paddingL),

                  /// Leader Cards
                  ...viewModel.leaders.asMap().entries.map((entry) {
                    final index = entry.key;
                    final leader = entry.value;
                    return LeaderboardWidgets.buildLeaderCard(
                      rank: leader['rank'],
                      name: leader['name'],
                      badge: leader['badge'],
                      isTopThree: index < 3,
                    );
                  }),

                  const SizedBox(height: AppDimensions.paddingXL),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}
class LeaderboardWidgets {
  /// 🔹 AppBar Section
  static Widget buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button with glassmorphism
          Material(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(10),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              ),
            ),
          ),

          const ResponsiveTextWidget(
            AppStrings.leaderBoard,
            textType: TextType.title,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: AppDimensions.textXL,
          ),

          // PRO badge with glow effect
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.accent, AppColors.accent.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium, color: Colors.white, size: 20),
                SizedBox(width: 6),
                ResponsiveTextWidget(
                  AppStrings.pro,
                  textType: TextType.body,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: AppDimensions.textS,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🔹 Background Image with Overlay
  static Widget buildBackground() {
    return Stack(
      children: [
        Image.asset(
          AppAssets.leaderboard,
          fit: BoxFit.cover,
          height: double.infinity,
          width: double.infinity,
        ),
        Container(
          color: Colors.black.withOpacity(0.4), // overlay for readability
        ),
      ],
    );
  }

  /// 🔹 Title Section with Enhanced Glass Effect
  static Widget buildTitle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingL,
        vertical: AppDimensions.paddingM,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events,
            color: Colors.amber.shade300,
            size: 32,
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Flexible(
            child: ResponsiveTextWidget(
              AppStrings.lunaFest2025,
              textType: TextType.heading,
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: AppDimensions.textXXL,
            ),
          ),
        ],
      ),
    );
  }

  /// 🔹 Podium Section for Top 3
  static Widget buildPodiumSection({
    required Map<String, dynamic> first,
    required Map<String, dynamic> second,
    required Map<String, dynamic> third,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _podiumItem(second['name'], "2nd"),
          _podiumItem(first['name'], "1st"),
          _podiumItem(third['name'], "3rd"),
        ],
      ),
    );
  }

  static Widget _podiumItem(String name, String place) {
    return Column(
      children: [
        const Icon(Icons.emoji_events, color: Colors.black, size: 32),
        const SizedBox(height: 6),
        ResponsiveTextWidget(
          name,
          textType: TextType.body,
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
        ResponsiveTextWidget(
          place,
          textType: TextType.caption,
          color: Colors.black54,
        ),
      ],
    );
  }


  /// 🔹 Leaderboard Card with Enhanced Design
  static Widget buildLeaderCard({
    required int rank,
    required String name,
    required String badge,
    bool isTopThree = false,
  }) {
    if (isTopThree && rank <= 3) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: AppDimensions.paddingXS,
        horizontal: AppDimensions.paddingM,
      ),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey.shade400,
            child: Text(
              rank.toString(),
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveTextWidget(
                  name,
                  textType: TextType.body,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
                ResponsiveTextWidget(
                  badge,
                  textType: TextType.caption,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
