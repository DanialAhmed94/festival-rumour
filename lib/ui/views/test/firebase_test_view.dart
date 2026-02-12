import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/firebase_test_service.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/widgets/responsive_text_widget.dart';

class FirebaseTestView extends StatefulWidget {
  const FirebaseTestView({super.key});

  @override
  State<FirebaseTestView> createState() => _FirebaseTestViewState();
}

class _FirebaseTestViewState extends State<FirebaseTestView> {
  FirebaseTestResult? _connectionResult;
  FirebaseTestResult? _authResult;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _testFirebase();
  }

  Future<void> _testFirebase() async {
    setState(() {
      _isLoading = true;
    });

    // Test Firebase connection
    final connectionResult = await FirebaseTestService.testFirebaseConnection();
    
    // Test Firebase Auth
    final authResult = await FirebaseTestService.testFirebaseAuth();

    setState(() {
      _connectionResult = connectionResult;
      _authResult = authResult;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const ResponsiveTextWidget(
          AppStrings.firebaseTest,
          textType: TextType.title,
          fontWeight: FontWeight.bold,
          color: AppColors.onPrimary,
        ),
        backgroundColor: AppColors.screenBackground,
        foregroundColor: AppColors.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _testFirebase,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTestCard(
                    title: AppStrings.firebaseConnectionTest,
                    result: _connectionResult,
                    icon: Icons.cloud,
                  ),
                  const SizedBox(height: AppDimensions.paddingM),
                  _buildTestCard(
                    title: AppStrings.firebaseAuthTest,
                    result: _authResult,
                    icon: Icons.security,
                  ),
                  const SizedBox(height: AppDimensions.paddingL),
                  _buildSummaryCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildTestCard({
    required String title,
    required FirebaseTestResult? result,
    required IconData icon,
  }) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: result?.isSuccess == true ? Colors.green : AppColors.red,
                  size: AppDimensions.iconM,
                ),
                const SizedBox(width: AppDimensions.paddingS),
                Expanded(
                  child: ResponsiveTextWidget(
                    title,
                    textType: TextType.title,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onPrimary,
                  ),
                ),
                if (result != null)
                  Icon(
                    result.isSuccess ? Icons.check_circle : Icons.error,
                    color: result.isSuccess ? Colors.green : AppColors.red,
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingS),
            if (result != null) ...[
              ResponsiveTextWidget(
                result.message,
                textType: TextType.body,
                fontWeight: FontWeight.w600,
                color: result.isSuccess ? Colors.green : AppColors.red,
              ),
              const SizedBox(height: AppDimensions.paddingS),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.paddingS),
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                ),
                child: ResponsiveTextWidget(
                  result.details,
                  textType: TextType.caption,
                  color: AppColors.grey700,
                ),
              ),
            ] else
              const ResponsiveTextWidget(
                AppStrings.testing,
                textType: TextType.body,
                color: AppColors.grey600,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final connectionSuccess = _connectionResult?.isSuccess ?? false;
    final authSuccess = _authResult?.isSuccess ?? false;
    final overallSuccess = connectionSuccess && authSuccess;

    return Card(
      elevation: 4,
      color: overallSuccess ? Colors.green.withOpacity(0.1) : AppColors.red.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  overallSuccess ? Icons.check_circle : Icons.error,
                  color: overallSuccess ? Colors.green : AppColors.red,
                  size: AppDimensions.iconXL,
                ),
                const SizedBox(width: AppDimensions.paddingS),
                Expanded(
                  child: ResponsiveTextWidget(
                    overallSuccess ? AppStrings.firebaseWorking : AppStrings.firebaseIssuesDetected,
                    textType: TextType.title,
                    fontWeight: FontWeight.bold,
                    color: overallSuccess ? Colors.green : AppColors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingS),
            ResponsiveTextWidget(
              overallSuccess
                  ? AppStrings.firebaseWorkingDescription
                  : AppStrings.firebaseIssuesDescription,
              textType: TextType.body,
              color: AppColors.grey700,
            ),
            const SizedBox(height: AppDimensions.paddingM),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testFirebase,
                    icon: const Icon(Icons.refresh),
                    label: const ResponsiveTextWidget(
                      AppStrings.retest,
                      textType: TextType.caption,
                      fontWeight: FontWeight.bold,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.screenBackground,
                      foregroundColor: AppColors.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.paddingS),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const ResponsiveTextWidget(
                      AppStrings.goBack,
                      textType: TextType.caption,
                      fontWeight: FontWeight.bold,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.grey600,
                      foregroundColor: AppColors.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
