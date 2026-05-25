import 'package:festival_rumour/core/constants/app_colors.dart';
import 'package:festival_rumour/core/constants/app_sizes.dart';
import 'package:festival_rumour/core/di/locator.dart';
import 'package:festival_rumour/core/services/geocoding_service.dart';
import 'package:festival_rumour/shared/widgets/responsive_text_widget.dart';
import 'package:festival_rumour/shared/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Full-screen picker: tap map to set pin, confirm to reverse-geocode into a street address line.
class JobLocationMapPickerScreen extends StatefulWidget {
  const JobLocationMapPickerScreen({super.key});

  /// Pushes picker; returns formatted address line or null if cancelled / failed confirm.
  static Future<String?> open(BuildContext context) {
    return Navigator.of(context).push<String?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const JobLocationMapPickerScreen(),
      ),
    );
  }

  static const LatLng _defaultCamera = LatLng(51.5072, -0.1276);

  @override
  State<JobLocationMapPickerScreen> createState() =>
      _JobLocationMapPickerScreenState();
}

class _JobLocationMapPickerScreenState extends State<JobLocationMapPickerScreen> {
  final GeocodingService _geocoding = locator<GeocodingService>();
  GoogleMapController? _mapController;

  LatLng _cameraTarget = JobLocationMapPickerScreen._defaultCamera;
  LatLng? _markerPosition;
  bool _centeringGps = false;
  bool _resolvingAddress = false;

  Future<void> _tryUseCurrentLocation({required bool centerMap}) async {
    if (_centeringGps) return;
    _centeringGps = true;

    LatLng target = JobLocationMapPickerScreen._defaultCamera;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _centeringGps = false;
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _centeringGps = false;
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      target = LatLng(position.latitude, position.longitude);
      if (!mounted) {
        _centeringGps = false;
        return;
      }
      setState(() {
        _cameraTarget = target;
        _markerPosition = target;
      });
      if (centerMap) {
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(target, 14),
        );
      }
    } catch (_) {
      // GPS / map unavailable: keep London default camera
    } finally {
      _centeringGps = false;
    }
  }

  Future<void> _confirmSelection() async {
    final latLng = _markerPosition;
    if (latLng == null || !mounted) return;

    setState(() => _resolvingAddress = true);

    try {
      final address = await _geocoding.getAddressLineFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      if (!mounted) return;

      if (address != null && address.isNotEmpty) {
        Navigator.of(context).pop(address);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not resolve an address here. Pick another spot or type the location manually.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _resolvingAddress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{};
    if (_markerPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('job_location_pick'),
          position: _markerPosition!,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.screenBackground,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFC2E95),
        foregroundColor: AppColors.white,
        iconTheme: const IconThemeData(color: AppColors.white),
        actionsIconTheme: const IconThemeData(color: AppColors.white),
        elevation: 0,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          style: IconButton.styleFrom(foregroundColor: AppColors.white),
          icon: const Icon(Icons.close, color: AppColors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        automaticallyImplyLeading: false,
        title: ResponsiveTextWidget(
          'Pick location',
          textType: TextType.title,
          color: AppColors.white,
          fontWeight: FontWeight.bold,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          fontSize: context.isSmallScreen
              ? AppDimensions.textM
              : AppDimensions.textL,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimensions.paddingM,
              AppDimensions.paddingS,
              AppDimensions.paddingM,
              AppDimensions.paddingS,
            ),
            child: ResponsiveTextWidget(
              'Tap on the map to place the marker, then tap "Use this address". '
              'You can still edit the Location field afterwards.',
              textType: TextType.body,
              color: AppColors.black.withOpacity(0.75),
              fontSize:
                  context.isSmallScreen ? AppDimensions.textS : AppDimensions.textM,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingS,
              ),
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusL),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _cameraTarget,
                    zoom: 12,
                  ),
                  onMapCreated: (controller) async {
                    _mapController = controller;
                    await _tryUseCurrentLocation(centerMap: true);
                  },
                  markers: markers,
                  onTap: (position) =>
                      setState(() => _markerPosition = position),
                  myLocationButtonEnabled: false,
                  myLocationEnabled: false,
                  mapToolbarEnabled: false,
                  mapType: MapType.normal,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(
                context.isSmallScreen
                    ? AppDimensions.paddingM
                    : AppDimensions.paddingL,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: !_resolvingAddress && _markerPosition != null
                      ? _confirmSelection
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFC2E95),
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.paddingM,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusL),
                    ),
                  ),
                  child: _resolvingAddress
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.black,
                          ),
                        )
                      : ResponsiveTextWidget(
                          'Use this address',
                          textType: TextType.body,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                          fontSize:
                              context.isSmallScreen ? AppDimensions.textM : AppDimensions.textL,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
