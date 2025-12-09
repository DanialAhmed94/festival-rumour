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
    // Request location permission when view is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      viewModel.requestLocationPermission();
    });
  }

  @override
  Widget buildView(BuildContext context, MapViewModel viewModel) {
    // Get selected festival from provider and set location
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
      final selectedFestival = festivalProvider.selectedFestival;
      
      // Set festival location if available and not already set
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
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          // Google Maps - Full screen
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: viewModel.festivalLocation ?? const LatLng(-33.8688, 151.2093),
              zoom: viewModel.festivalLocation != null ? 15.0 : 11.0,
            ),
            markers: viewModel.markers,
            polylines: viewModel.polylines,
            myLocationButtonEnabled: false,
            myLocationEnabled: viewModel.isLocationPermissionGranted,
            zoomControlsEnabled: false, // Enable zoom controls for debugging
            mapToolbarEnabled: false,
            mapType: MapType.normal,
            onMapCreated: (GoogleMapController controller) {
              debugPrint('🗺️ GoogleMap created successfully');
              viewModel.setMapController(controller);
              // Center on festival location if available, otherwise center on current location
              if (viewModel.festivalLocation != null) {
                debugPrint('🗺️ Centering on festival location: ${viewModel.festivalLocation}');
                viewModel.centerOnFestivalLocation();
              } else if (viewModel.isLocationPermissionGranted) {
                debugPrint('🗺️ Centering on current location');
                viewModel.centerOnCurrentLocation();
              }
            },
            onTap: (LatLng position) {
              // Handle map tap if needed
            },
            onCameraMoveStarted: () {
              debugPrint('🗺️ Map camera started moving');
            },
            onCameraIdle: () {
              debugPrint('🗺️ Map camera idle');
            },
          ),

          // Overlay content
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                const Spacer(),
              ],
            ),
          ),

          // Floating action buttons
          Positioned(
            bottom: 20,
            right: 20,
            child: _buildDirectionButton(context, viewModel),
          ),
          
          // Navigate button (if festival location is available)
          if (viewModel.festivalLocation != null)
            Positioned(
              bottom: 20,
              left: 20,
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

  Widget _buildOverlay(BuildContext context) {
    return Positioned(
      left: 50,
      top: 100,
      child: Container(
        width: AppDimensions.imageXXL,
        height: AppDimensions.imageXXL,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.grey600.withOpacity(0.3),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                ),
                child: const ResponsiveTextWidget(
                  '</>',
                  textType: TextType.body,
                  color: AppColors.black,
                  fontSize: AppDimensions.textXL,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppDimensions.spaceS),
              const ResponsiveTextWidget(
                'Code with joy',
                textType: TextType.body,
                color: AppColors.white,
                fontSize: AppDimensions.textM,
                fontWeight: FontWeight.w600,
              ),
            ],
          ),
        ),
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

  Future<void> _navigateToFestivalLocation(
    BuildContext context,
    MapViewModel viewModel,
  ) async {
    if (viewModel.festivalLocation == null) return;

    try {
      final lat = viewModel.festivalLocation!.latitude;
      final lng = viewModel.festivalLocation!.longitude;
      
      // Create Google Maps URL for navigation
      final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: ResponsiveTextWidget(
                'Could not open navigation app',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: ResponsiveTextWidget('Error opening navigation: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _requestLocationAndShowDirections(
    BuildContext context,
    MapViewModel viewModel,
  ) async {
    // Check if festival location is available
    if (viewModel.festivalLocation == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: ResponsiveTextWidget(
              'Festival location not available',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      // Request location permission
      final permission = await Permission.location.request();

      if (permission.isGranted) {
        // Get current location
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final userLocation = LatLng(position.latitude, position.longitude);

        // Show directions to festival location
        await viewModel.showDirections(userLocation, viewModel.festivalLocation!);

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: ResponsiveTextWidget(
                'Directions shown to festival location',
              ),
              backgroundColor: AppColors.buttonYellow,
            ),
          );
        }
      } else {
        // Show permission denied message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: ResponsiveTextWidget(
                'Location permission is required to show directions',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: ResponsiveTextWidget('Error getting location: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
