import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/viewmodels/base_view_model.dart';

class MapViewModel extends BaseViewModel {
  GoogleMapController? _mapController;

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  bool _isLocationPermissionGranted = false;
  LatLng? _currentLocation;
  LatLng? _festivalLocation;
  String? _festivalTitle;

  bool _isAnimatingCamera = false; // 🔥 Prevent animation loop

  GoogleMapController? get mapController => _mapController;
  Set<Polyline> get polylines => _polylines;
  Set<Marker> get markers => _markers;
  bool get isLocationPermissionGranted => _isLocationPermissionGranted;
  LatLng? get currentLocation => _currentLocation;
  LatLng? get festivalLocation => _festivalLocation;
  String? get festivalTitle => _festivalTitle;

  void setMapController(GoogleMapController controller) {
    _mapController = controller;
    notifyListeners();
  }

  void animateToLocation(LatLng location) {
    _mapController?.animateCamera(CameraUpdate.newLatLng(location));
  }

  void animateToLocationWithZoom(LatLng location, double zoom) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(location, zoom));
  }

  // 🚀 SAFE DIRECTIONS METHOD — NO MEMORY LEAK
  Future<void> showDirections(
    LatLng userLocation,
    LatLng festivalLocation,
  ) async {
    if (_isAnimatingCamera) return;
    _isAnimatingCamera = true;

    // Polylines
    _polylines = {
      Polyline(
        polylineId: const PolylineId('directions'),
        points: [userLocation, festivalLocation],
        color: const Color(0xFF8B5CF6),
        width: 5,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };

    // Markers
    _markers = {
      Marker(
        markerId: const MarkerId('user_location'),
        position: userLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ),
      Marker(
        markerId: const MarkerId('festival_destination'),
        position: festivalLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Festival Location'),
      ),
    };

    // Bounds
    final bounds = _calculateBounds([userLocation, festivalLocation]);

    try {
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80),
      );
    } catch (e) {
      // Fallback zoom if bounds crash
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(festivalLocation, 14),
      );
    }

    _isAnimatingCamera = false;
    notifyListeners(); // OK here, after animation done
  }

  // SAFE BOUNDS (prevents crash when both points same)
  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    // If both points nearly same → add small padding to avoid crash
    if ((maxLat - minLat).abs() < 0.0001 && (maxLng - minLng).abs() < 0.0001) {
      return LatLngBounds(
        southwest: LatLng(minLat - 0.001, minLng - 0.001),
        northeast: LatLng(maxLat + 0.001, maxLng + 0.001),
      );
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void clearDirections() {
    _polylines.clear();
    _markers.clear();
    notifyListeners();
  }

  // LOCATION PERMISSION
  Future<bool> requestLocationPermission() async {
    try {
      final permission = await Permission.location.request();

      if (permission.isGranted) {
        _isLocationPermissionGranted = true;
        await _getCurrentLocation();
      } else {
        _isLocationPermissionGranted = false;
      }

      notifyListeners();
      return _isLocationPermissionGranted;
    } catch (e) {
      _isLocationPermissionGranted = false;
      notifyListeners();
      return false;
    }
  }

  // GET CURRENT LOCATION
  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentLocation = LatLng(position.latitude, position.longitude);

      // ❌ REMOVE THIS → it breaks your logic
      // if (_mapController != null) {
      //   await _mapController!.animateCamera(
      //     CameraUpdate.newLatLngZoom(_currentLocation!, 15),
      //   );
      // }

      notifyListeners();
    } catch (e) {
      _currentLocation = null;
      notifyListeners();
    }
  }

  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<void> centerOnCurrentLocation() async {
    if (_currentLocation != null && _mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 15),
      );
    } else if (_isLocationPermissionGranted) {
      await _getCurrentLocation();
    }
  }

  // SET FESTIVAL LOCATION
  void setFestivalLocation(String? latitude, String? longitude, String? title) {
    if (latitude == null || longitude == null) return;

    final lat = double.tryParse(latitude);
    final lng = double.tryParse(longitude);

    if (lat == null || lng == null) return;

    _festivalLocation = LatLng(lat, lng);
    _festivalTitle = title;

    _markers = {
      Marker(
        markerId: const MarkerId('festival_location'),
        position: _festivalLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: _festivalTitle ?? 'Festival Location',
          snippet: 'Tap marker to navigate',
        ),
      ),
    };

    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_festivalLocation!, 15),
      );
    }

    notifyListeners();
  }

  Future<void> centerOnFestivalLocation() async {
    if (_festivalLocation != null && _mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_festivalLocation!, 15),
      );
    }
  }
}
