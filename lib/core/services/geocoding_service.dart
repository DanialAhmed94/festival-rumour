import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';

/// Service for converting coordinates to address (reverse geocoding)
class GeocodingService {
  static final GeocodingService _instance = GeocodingService._internal();
  factory GeocodingService() => _instance;
  GeocodingService._internal();

  /// Cache for location lookups to avoid repeated API calls
  final Map<String, String> _locationCache = {};

  /// Convert latitude and longitude to city and country name
  /// Returns format: "City, Country" or "Location TBD" if unable to resolve
  Future<String> getLocationFromCoordinates(
    String? latitude,
    String? longitude,
  ) async {
    if (latitude == null || longitude == null || latitude.isEmpty || longitude.isEmpty) {
      return 'Location TBD';
    }

    // Check cache first
    final cacheKey = '$latitude,$longitude';
    if (_locationCache.containsKey(cacheKey)) {
      return _locationCache[cacheKey]!;
    }

    try {
      final lat = double.tryParse(latitude);
      final lng = double.tryParse(longitude);

      if (lat == null || lng == null) {
        return 'Location TBD';
      }

      // Perform reverse geocoding
      final placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isEmpty) {
        return 'Location TBD';
      }

      final placemark = placemarks.first;
      final city = placemark.locality ?? placemark.subAdministrativeArea ?? '';
      final country = placemark.country ?? '';

      String location;
      if (city.isNotEmpty && country.isNotEmpty) {
        location = '$city, $country';
      } else if (city.isNotEmpty) {
        location = city;
      } else if (country.isNotEmpty) {
        location = country;
      } else {
        location = 'Location TBD';
      }

      // Cache the result
      _locationCache[cacheKey] = location;

      if (kDebugMode) {
        print('Geocoded location: $location from ($lat, $lng)');
      }

      return location;
    } catch (e) {
      if (kDebugMode) {
        print('Error geocoding location: $e');
      }
      return 'Location TBD';
    }
  }

  /// Clear the location cache
  void clearCache() {
    _locationCache.clear();
  }
}

