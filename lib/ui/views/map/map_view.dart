import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/base_view.dart';
import '../../../shared/widgets/responsive_text_widget.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/backbutton.dart';
import '../../../core/providers/festival_provider.dart';
import 'map_view_model.dart';

class MapView extends BaseView<MapViewModel> {
  final VoidCallback? onBack;
  const MapView({super.key, this.onBack});

  @override
  MapViewModel createViewModel() => MapViewModel();

  @override
  void onViewModelReady(MapViewModel viewModel) {
    super.onViewModelReady(viewModel);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      viewModel.requestLocationPermission();
    });
  }

  @override
  Widget buildView(BuildContext context, MapViewModel viewModel) {
    // Fetch festival location
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final festivalProvider = Provider.of<FestivalProvider>(
        context,
        listen: false,
      );
      final selectedFestival = festivalProvider.selectedFestival;

      if (selectedFestival != null &&
          selectedFestival.latitude != null &&
          selectedFestival.longitude != null &&
          viewModel.festivalLocation == null) {
        viewModel.setFestivalLocation(
          selectedFestival.latitude,
          selectedFestival.longitude,
          selectedFestival.title,
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      body: Stack(
        children: [
          /// -------------------------------------------
          /// SAFE GOOGLE MAP WIDGET (does NOT rebuild)
          /// -------------------------------------------
          viewModel.festivalLocation == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.black),
                )
              : _StaticGoogleMap(viewModel: viewModel),

          // Overlay content
          SafeArea(
            child: Column(children: [_buildAppBar(context), const Spacer()]),
          ),

          // // Right-side directions button
          // Positioned(
          //   bottom: 20,
          //   right: 20,
          //   child: _buildDirectionButton(context, viewModel),
          // ),

          // Left-side open maps button
          if (viewModel.festivalLocation != null)
            Positioned(
              bottom: 20,
              right: 20,
              child: _buildNavigateButton(context, viewModel),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: Row(
        children: [
          CustomBackButton(onTap: onBack ?? () => Navigator.pop(context)),
          const SizedBox(width: AppDimensions.spaceM),
          const ResponsiveTextWidget(
            'Location',
            textType: TextType.body,
            color: AppColors.black,
            fontSize: AppDimensions.textL,
            fontWeight: FontWeight.w600,
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionButton(BuildContext context, MapViewModel viewModel) {
    return FloatingActionButton(
      onPressed: () => _requestLocationAndShowDirections(context, viewModel),
      backgroundColor: AppColors.buttonYellow,
      child: const Icon(
        Icons.directions,
        color: AppColors.black,
        size: AppDimensions.iconL,
      ),
    );
  }

  Widget _buildNavigateButton(BuildContext context, MapViewModel viewModel) {
    return FloatingActionButton(
      onPressed: () => _navigateToFestivalLocation(context, viewModel),
      backgroundColor: AppColors.accent,
      child: const Icon(
        Icons.navigation,
        color: AppColors.white,
        size: AppDimensions.iconL,
      ),
    );
  }

  // ---------------------------------------------------------
  // NAVIGATION TO GOOGLE MAPS APP
  // ---------------------------------------------------------
  Future<void> _navigateToFestivalLocation(
    BuildContext context,
    MapViewModel viewModel,
  ) async {
    if (viewModel.festivalLocation == null) return;

    try {
      final lat = viewModel.festivalLocation!.latitude;
      final lng = viewModel.festivalLocation!.longitude;

      final url = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving",
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: ResponsiveTextWidget("Could not open navigation app"),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: ResponsiveTextWidget("Error opening navigation: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------
  // SHOW DIRECTIONS (DRAW POLYLINE)
  // ---------------------------------------------------------
  Future<void> _requestLocationAndShowDirections(
    BuildContext context,
    MapViewModel viewModel,
  ) async {
    if (viewModel.festivalLocation == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: ResponsiveTextWidget("Festival location not available"),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      // Permission
      final permission = await Permission.location.request();
      if (!permission.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: ResponsiveTextWidget("Location permission is required"),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Get user location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      final userLocation = LatLng(position.latitude, position.longitude);

      // Draw polyline
      await viewModel.showDirections(userLocation, viewModel.festivalLocation!);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: ResponsiveTextWidget(
              "Directions shown to festival location",
            ),
            backgroundColor: AppColors.buttonYellow,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: ResponsiveTextWidget("Error getting location: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

/// =======================================================================
/// STATIC GOOGLE MAP WIDGET (DOES NOT REBUILD = NO MEMORY CRASH)
/// =======================================================================
class _StaticGoogleMap extends StatelessWidget {
  final MapViewModel viewModel;
  const _StaticGoogleMap({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: viewModel.festivalLocation!,
          zoom: viewModel.festivalLocation != null ? 15 : 11,
        ),

        markers: viewModel.markers,
        polylines: viewModel.polylines,
        myLocationButtonEnabled: false,
        myLocationEnabled: viewModel.isLocationPermissionGranted,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        mapType: MapType.normal,
        onMapCreated: (controller) {
          viewModel.setMapController(controller);

          if (viewModel.festivalLocation != null) {
            viewModel.centerOnFestivalLocation();
          } else if (viewModel.isLocationPermissionGranted) {
            viewModel.centerOnCurrentLocation();
          }
        },
      ),
    );
  }
}
