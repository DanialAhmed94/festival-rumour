/// API Configuration constants
class ApiConfig {
  // Base URL -
  static const String baseUrl = 'https://stagingcrapadvisor.semicolonstech.com/api';
  
  // Image Base URL - Base URL for festival images
  static const String imageBaseUrl = 'https://stagingcrapadvisor.semicolonstech.com/asset/festivals/';
  

  
  // API Endpoints
  static const String getFestivals = '/getfestival';

  
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

