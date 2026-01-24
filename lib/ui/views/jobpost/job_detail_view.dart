import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/base_view.dart';
import '../../../core/utils/backbutton.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../shared/extensions/context_extensions.dart';

class JobDetailView extends StatelessWidget {
  final Map<String, dynamic> jobData;
  
  const JobDetailView({super.key, required this.jobData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: SafeArea(
          bottom: false,
          child: Container(
            color: const Color(0xFFFC2E95),
            padding: EdgeInsets.symmetric(
              horizontal:
                  context.isSmallScreen ? AppDimensions.paddingS : AppDimensions.paddingM,
              vertical: AppDimensions.paddingS,
            ),
            child: Row(
              children: [
                CustomBackButton(onTap: () => Navigator.pop(context)),
                const SizedBox(width: AppDimensions.spaceS),
                Expanded(
                  child: ResponsiveTextWidget(
                    'Job Details',
                    textType: TextType.title,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(
          context.isSmallScreen ? AppDimensions.paddingM : AppDimensions.paddingL,
        ),
        child: _buildJobDetailCard(context),
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
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(
          color: AppColors.black.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                      color: AppColors.black,
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
                      color: AppColors.black,
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
                  color: AppColors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                  border: Border.all(
                    color: AppColors.black.withOpacity(0.18),
                    width: 1.5,
                  ),
                ),
                child: ResponsiveTextWidget(
                  jobData['category'] ?? '',
                  textType: TextType.body,
                  fontSize: context.isSmallScreen 
                      ? AppDimensions.textS 
                      : AppDimensions.textM,
                  color: AppColors.black,
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
            color: AppColors.black.withOpacity(0.15),
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
                    color: AppColors.grey100,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                    border: Border.all(
                      color: AppColors.black.withOpacity(0.12),
                      width: 1,
                    ),
                  ),
                  child: ResponsiveTextWidget(
                    jobData['description'] as String,
                    textType: TextType.body,
                    fontSize: context.isSmallScreen 
                        ? AppDimensions.textM 
                        : AppDimensions.textL,
                    color: AppColors.black.withOpacity(0.85),
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
                    color: AppColors.grey100,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                    border: Border.all(
                      color: AppColors.black.withOpacity(0.12),
                      width: 1,
                    ),
                  ),
                  child: ResponsiveTextWidget(
                    jobData['requirements'] as String,
                    textType: TextType.body,
                    fontSize: context.isSmallScreen 
                        ? AppDimensions.textM 
                        : AppDimensions.textL,
                    color: AppColors.black.withOpacity(0.85),
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
          color: AppColors.black,
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
              color: AppColors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            ),
            child: Icon(
              icon,
              color: AppColors.black,
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
                  color: AppColors.black.withOpacity(0.6),
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
                  color: AppColors.black.withOpacity(0.85),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
