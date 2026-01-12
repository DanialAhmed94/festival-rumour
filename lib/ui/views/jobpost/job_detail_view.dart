import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/extensions/context_extensions.dart';

class JobDetailView extends StatelessWidget {
  final Map<String, dynamic> jobData;
  
  const JobDetailView({super.key, required this.jobData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove back button
        title: const ResponsiveTextWidget(
          'Job Details',
          textType: TextType.title,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
        actions: [
          // White cross button on top right
          Padding(
            padding: EdgeInsets.only(
              right: context.isSmallScreen 
                  ? AppDimensions.paddingS 
                  : AppDimensions.paddingM,
            ),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: context.isSmallScreen ? 32 : 36,
                height: context.isSmallScreen ? 32 : 36,
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.close,
                  color: AppColors.black,
                  size: context.isSmallScreen ? 20 : 24,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              AppAssets.bottomsheet,
              fit: BoxFit.cover,
            ),
          ),
          // Dark overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.4),
            ),
          ),
          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(
                context.isSmallScreen 
                    ? AppDimensions.paddingM 
                    : AppDimensions.paddingL,
              ),
              child: _buildJobDetailCard(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobDetailCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        context.isSmallScreen 
            ? AppDimensions.paddingM 
            : AppDimensions.paddingL,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.black.withOpacity(0.9),
            AppColors.black.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(
          color: AppColors.yellow.withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.yellow.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ResponsiveTextWidget(
                      jobData['title'] ?? 'Untitled Job',
                      textType: TextType.heading,
                      fontSize: context.isSmallScreen 
                          ? AppDimensions.textL 
                          : AppDimensions.textXL,
                      fontWeight: FontWeight.bold,
                      color: AppColors.yellow,
                    ),
                    SizedBox(height: context.isSmallScreen 
                        ? AppDimensions.spaceS 
                        : AppDimensions.spaceM),
                    ResponsiveTextWidget(
                      jobData['company'] ?? '',
                      textType: TextType.body,
                      fontSize: context.isSmallScreen 
                          ? AppDimensions.textM 
                          : AppDimensions.textL,
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ],
                ),
              ),
              // Category badge
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.isSmallScreen 
                      ? AppDimensions.paddingS 
                      : AppDimensions.paddingM,
                  vertical: AppDimensions.paddingS,
                ),
                decoration: BoxDecoration(
                  color: AppColors.yellow.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                  border: Border.all(
                    color: AppColors.yellow.withOpacity(0.6),
                    width: 1.5,
                  ),
                ),
                child: ResponsiveTextWidget(
                  jobData['category'] ?? '',
                  textType: TextType.body,
                  fontSize: context.isSmallScreen 
                      ? AppDimensions.textS 
                      : AppDimensions.textM,
                  color: AppColors.yellow,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          SizedBox(height: context.isSmallScreen 
              ? AppDimensions.paddingM 
              : AppDimensions.paddingL),
          
          // Divider
          Divider(
            color: AppColors.yellow.withOpacity(0.4),
            thickness: 2,
            height: 2,
          ),
          
          SizedBox(height: context.isSmallScreen 
              ? AppDimensions.paddingM 
              : AppDimensions.paddingL),
          
          // Job Details Section
          _buildDetailSection(
            context,
            'Job Information',
            [
              if (jobData['jobType'] != null && (jobData['jobType'] as String).isNotEmpty)
                _buildDetailItem(
                  context,
                  Icons.work_outline,
                  'Job Type',
                  jobData['jobType'] as String,
                ),
              if (jobData['location'] != null && (jobData['location'] as String).isNotEmpty)
                _buildDetailItem(
                  context,
                  Icons.location_on,
                  'Location',
                  jobData['location'] as String,
                ),
              if (jobData['salary'] != null && (jobData['salary'] as String).isNotEmpty)
                _buildDetailItem(
                  context,
                  Icons.attach_money,
                  'Salary',
                  jobData['salary'] as String,
                ),
              if (jobData['festivalDate'] != null && (jobData['festivalDate'] as String).isNotEmpty)
                _buildDetailItem(
                  context,
                  Icons.calendar_today,
                  'Festival Date',
                  jobData['festivalDate'] as String,
                ),
            ],
          ),
          
          if (jobData['description'] != null && (jobData['description'] as String).isNotEmpty) ...[
            SizedBox(height: context.isSmallScreen 
                ? AppDimensions.paddingM 
                : AppDimensions.paddingL),
            _buildDetailSection(
              context,
              'Description',
              [
                Container(
                  padding: EdgeInsets.all(AppDimensions.paddingM),
                  decoration: BoxDecoration(
                    color: AppColors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                    border: Border.all(
                      color: AppColors.yellow.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: ResponsiveTextWidget(
                    jobData['description'] as String,
                    textType: TextType.body,
                    fontSize: context.isSmallScreen 
                        ? AppDimensions.textM 
                        : AppDimensions.textL,
                    color: AppColors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ],
          
          if (jobData['requirements'] != null && (jobData['requirements'] as String).isNotEmpty) ...[
            SizedBox(height: context.isSmallScreen 
                ? AppDimensions.paddingM 
                : AppDimensions.paddingL),
            _buildDetailSection(
              context,
              'Requirements',
              [
                Container(
                  padding: EdgeInsets.all(AppDimensions.paddingM),
                  decoration: BoxDecoration(
                    color: AppColors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                    border: Border.all(
                      color: AppColors.yellow.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: ResponsiveTextWidget(
                    jobData['requirements'] as String,
                    textType: TextType.body,
                    fontSize: context.isSmallScreen 
                        ? AppDimensions.textM 
                        : AppDimensions.textL,
                    color: AppColors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ],
          
          if (jobData['contact'] != null && (jobData['contact'] as String).isNotEmpty) ...[
            SizedBox(height: context.isSmallScreen 
                ? AppDimensions.paddingM 
                : AppDimensions.paddingL),
            _buildDetailSection(
              context,
              'Contact Information',
              [
                _buildDetailItem(
                  context,
                  Icons.contact_mail,
                  'Contact',
                  jobData['contact'] as String,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResponsiveTextWidget(
          title,
          textType: TextType.body,
          fontSize: context.isSmallScreen 
              ? AppDimensions.textL 
              : AppDimensions.textXL,
          fontWeight: FontWeight.bold,
          color: AppColors.yellow,
        ),
        SizedBox(height: context.isSmallScreen 
            ? AppDimensions.paddingS 
            : AppDimensions.paddingM),
        ...children,
      ],
    );
  }

  Widget _buildDetailItem(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: context.isSmallScreen 
            ? AppDimensions.paddingS 
            : AppDimensions.paddingM,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(context.isSmallScreen ? 6 : 8),
            decoration: BoxDecoration(
              color: AppColors.yellow.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            ),
            child: Icon(
              icon,
              color: AppColors.yellow,
              size: context.isSmallScreen ? 18 : 20,
            ),
          ),
          SizedBox(width: context.isSmallScreen 
              ? AppDimensions.paddingS 
              : AppDimensions.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveTextWidget(
                  label,
                  textType: TextType.caption,
                  fontSize: context.isSmallScreen 
                      ? AppDimensions.textS 
                      : AppDimensions.textM,
                  color: AppColors.yellow.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                ),
                SizedBox(height: context.isSmallScreen 
                    ? AppDimensions.spaceXS 
                    : AppDimensions.spaceS),
                ResponsiveTextWidget(
                  value,
                  textType: TextType.body,
                  fontSize: context.isSmallScreen 
                      ? AppDimensions.textM 
                      : AppDimensions.textL,
                  color: AppColors.white.withOpacity(0.9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
