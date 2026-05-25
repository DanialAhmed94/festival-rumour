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

  /// Reverse-geocode to a single-line postal-style address for forms (job location, etc.).
  /// Returns null if lookup fails or result would be unusable.
  Future<String?> getAddressLineFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;
      final line = formatPlacemarkAsSingleLine(placemarks.first).trim();
      if (line.isEmpty) return null;
      return line;
    } catch (e) {
      if (kDebugMode) {
        print('Error reverse geocoding coordinates: $e');
      }
      return null;
    }
  }

  /// Human-readable street / city line from platform [Placemark].
  String formatPlacemarkAsSingleLine(Placemark p) {
    String? z(String? s) {
      final t = s?.trim();
      if (t == null || t.isEmpty) return null;
      return t;
    }

    final streetFromParts = '${z(p.subThoroughfare) ?? ''} ${z(p.thoroughfare) ?? ''}'.trim();
    final streetLine = z(p.street) ??
        (streetFromParts.isNotEmpty ? streetFromParts : null) ??
        z(p.name);

    final parts = <String>[];
    void add(String? s) {
      final t = z(s);
      if (t != null && !parts.contains(t)) parts.add(t);
    }

    add(streetLine);

    final city = z(p.locality) ?? z(p.subAdministrativeArea);
    add(city);

    final postal = z(p.postalCode);
    if (postal != null) add(postal);

    final region = z(p.administrativeArea);
    if (region != null && region != city) add(region);

    add(z(p.country));

    return parts.join(', ');
  }

  /// Clear the location cache
  void clearCache() {
    _locationCache.clear();
  }
}

