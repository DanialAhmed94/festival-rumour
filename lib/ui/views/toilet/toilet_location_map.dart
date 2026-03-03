import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../core/constants/app_strings.dart';

/// Shows a small map with a marker at the toilet location, or a placeholder if coords are missing.
class ToiletLocationMap extends StatelessWidget {
  final String? latitude;
  final String? longitude;
  final double height;

  const ToiletLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 180,
  });

  double? get _lat => _parseDouble(latitude);
  double? get _lng => _parseDouble(longitude);
  bool get _hasValidLocation => _lat != null && _lng != null;

  static double? _parseDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    return double.tryParse(value.trim());
  }

  Future<void> _openInMaps(BuildContext context) async {
    if (!_hasValidLocation) return;
    try {
      final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${_lat},${_lng}&travelmode=driving',
      );
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: ResponsiveTextWidget('Could not open maps'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: ResponsiveTextWidget('Error opening maps: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasValidLocation) {
      return Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.grey600.withOpacity(0.2),
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        alignment: Alignment.center,
        child: ResponsiveTextWidget(
          AppStrings.locationNotAvailable,
          textType: TextType.caption,
          color: AppColors.grey600,
        ),
      );
    }

    final position = LatLng(_lat!, _lng!);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: position,
                zoom: 16,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('toilet'),
                  position: position,
                ),
              },
              myLocationButtonEnabled: false,
              myLocationEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              mapType: MapType.normal,
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openInMaps(context),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
