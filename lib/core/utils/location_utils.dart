import 'dart:math' show cos, sqrt;

/// Default radius in meters for "at festival" verification (1 km).
const double defaultFestivalRadiusMeters = 1000.0;

/// Returns distance between two points in meters (Haversine formula).
double distanceInMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const p = 0.017453292519943295; // pi / 180
  final a = 0.5 -
      cos((lat2 - lat1) * p) / 2 +
      cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
  return 12742000 * sqrt(a); // 2 * R * 1000; R = 6371 km
}

/// Returns true if (lat2, lon2) is within [radiusMeters] of (lat1, lon1).
bool isWithinRadius(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
  double radiusMeters,
) {
  return distanceInMeters(lat1, lon1, lat2, lon2) <= radiusMeters;
}
