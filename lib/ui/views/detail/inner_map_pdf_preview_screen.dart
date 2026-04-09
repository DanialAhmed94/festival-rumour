import 'package:flutter/material.dart';
import 'package:flutter_cached_pdfview/flutter_cached_pdfview.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/pink_subpage_header.dart';

/// In-app PDF inner map (organizer app uses flutter_cached_pdfview).
class InnerMapPdfPreviewScreen extends StatelessWidget {
  final String pdfUrl;

  const InnerMapPdfPreviewScreen({
    super.key,
    required this.pdfUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PinkSubpageHeader(title: AppStrings.innerMap),
            Expanded(
              child: ColoredBox(
                color: AppColors.screenBackground,
                child: PDF(
                  enableSwipe: true,
                  swipeHorizontal: false,
                  autoSpacing: true,
                  pageFling: true,
                  onError: (error) {
                    debugPrint('Inner map PDF error: $error');
                  },
                ).cachedFromUrl(
                  pdfUrl,
                  placeholder: (double progress) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress / 100,
                          color: AppColors.black,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${progress.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  errorWidget: (dynamic error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                          const SizedBox(height: 16),
                          const Text(
                            'Could not load PDF',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            error?.toString() ?? '',
                            style: TextStyle(fontSize: 12, color: AppColors.grey600),
                            textAlign: TextAlign.center,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
