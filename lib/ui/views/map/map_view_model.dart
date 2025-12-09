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
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(location),
      );
    }
  }

  void animateToLocationWithZoom(LatLng location, double zoom) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(location, zoom),
      );
    }
  }

  Future<void> showDirections(LatLng userLocation, LatLng festivalLocation) async {
    // Create a polyline between user location and festival location
    _polylines = {
      Polyline(
        polylineId: const PolylineId('directions'),
        points: [userLocation, festivalLocation],
        color: const Color(0xFF8B5CF6), // Purple color for directions
        width: 5,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };

    // Add user location marker
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

    // Animate camera to show both locations
    if (_mapController != null) {
      final bounds = _calculateBounds([userLocation, festivalLocation]);
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0),
      );
    }

    notifyListeners();
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
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

  /// Request location permission and get current location
  Future<bool> requestLocationPermission() async {
    try {
      final permission = await Permission.location.request();
      
      if (permission.isGranted) {
        _isLocationPermissionGranted = true;
        await _getCurrentLocation();
        notifyListeners();
        return true;
      } else if (permission.isPermanentlyDenied) {
        // User permanently denied permission, show dialog to open settings
        _isLocationPermissionGranted = false;
        notifyListeners();
        return false;
      } else {
        _isLocationPermissionGranted = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLocationPermissionGranted = false;
      notifyListeners();
      return false;
    }
  }

  /// Get current user location
  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentLocation = LatLng(position.latitude, position.longitude);
      
      // Center map on user location
      if (_mapController != null && _currentLocation != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation!, 15.0),
        );
      }
      
      notifyListeners();
    } catch (e) {
      // Handle location error
      _currentLocation = null;
      notifyListeners();
    }
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Center map on current location
  Future<void> centerOnCurrentLocation() async {
    if (_currentLocation != null && _mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 15.0),
      );
    } else if (_isLocationPermissionGranted) {
      await _getCurrentLocation();
    }
  }

  /// Set festival location and show marker
  void setFestivalLocation(String? latitude, String? longitude, String? title) {
    if (latitude != null && longitude != null) {
      try {
        final lat = double.tryParse(latitude);
        final lng = double.tryParse(longitude);
        
        if (lat != null && lng != null) {
          _festivalLocation = LatLng(lat, lng);
          _festivalTitle = title;
          
          // Add festival marker with tap handler
          _markers = {
            Marker(
              markerId: const MarkerId('festival_location'),
              position: _festivalLocation!,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(
                title: _festivalTitle ?? 'Festival Location',
                snippet: 'Tap marker to navigate',
              ),
              onTap: () {
                // Marker tap handled in view layer
              },
            ),
          };
          
          // Center map on festival location
          if (_mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(_festivalLocation!, 15.0),
            );
          }
          
          notifyListeners();
        }
      } catch (e) {
        // Handle parsing error
        _festivalLocation = null;
        _festivalTitle = null;
      }
    }
  }

  /// Center map on festival location
  Future<void> centerOnFestivalLocation() async {
    if (_festivalLocation != null && _mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_festivalLocation!, 15.0),
      );
    }
  }
}
