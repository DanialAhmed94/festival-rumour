/// API Configuration constants
class ApiConfig {
  // Base URL -
  static const String baseUrl = 'https://stagingcrapadvisor.semicolonstech.com/api';
  
  // Image Base URL - Base URL for festival images
  static const String imageBaseUrl = 'https://stagingcrapadvisor.semicolonstech.com/asset/festivals/';
  

  
  // API Endpoints
  static const String getFestivals = '/getfestival';
  static const String getBulletins = '/bulletins-all';
  static const String getToilets = '/toilets-all';
  static const String getEvents = '/events-all';
  static const String getPerformances = '/performance-all';

  /// Toilet type and toilet image base URLs (no trailing slash)
  static const String toiletTypeImageBaseUrl = 'https://stagingcrapadvisor.semicolonstech.com/asset/toilet_types';
  static const String toiletImageBaseUrl = 'https://stagingcrapadvisor.semicolonstech.com/public/asset/toilets';
  static const String eventImageBaseUrl = 'https://stagingcrapadvisor.semicolonstech.com/public/asset/events';
  static const String performanceImageBaseUrl = 'https://stagingcrapadvisor.semicolonstech.com/public/asset/performances';

  /// Get full event image URL
  static String getEventImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    final clean = imagePath.startsWith('/') ? imagePath.substring(1) : imagePath;
    return '$eventImageBaseUrl/$clean';
  }

  /// Get full performance image URL
  static String getPerformanceImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    final clean = imagePath.startsWith('/') ? imagePath.substring(1) : imagePath;
    return '$performanceImageBaseUrl/$clean';
  }

  /// Get full toilet type image URL
  static String getToiletTypeImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    final clean = imagePath.startsWith('/') ? imagePath.substring(1) : imagePath;
    return '$toiletTypeImageBaseUrl/$clean';
  }

  /// Get full toilet image URL
  static String getToiletImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    final clean = imagePath.startsWith('/') ? imagePath.substring(1) : imagePath;
    return '$toiletImageBaseUrl/$clean';
  }

  /// Get full image URL from image path
  static String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return ''; // Return empty or placeholder image
    }
    
    // If image path already contains http/https, return as is
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    
    // Remove leading slash if present
    final cleanPath = imagePath.startsWith('/') ? imagePath.substring(1) : imagePath;
    
    // Construct full URL: baseUrl  + imagePath
    return '$imageBaseUrl/$cleanPath';
  }
  
  // Request timeout durations
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
  
  // Default headers
  static Map<String, dynamic> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // Get authorization header
  static Map<String, dynamic> getAuthHeaders(String? token) {
    final headers = Map<String, dynamic>.from(defaultHeaders);
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }
}

