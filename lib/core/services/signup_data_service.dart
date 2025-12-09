import 'package:flutter/foundation.dart';

/// Service to temporarily store signup data before creating Firebase user
class SignupDataService {
  static final SignupDataService _instance = SignupDataService._internal();
  factory SignupDataService() => _instance;
  SignupDataService._internal();

  String? _email;
  String? _password;
  String? _phoneNumber;
  String? _displayName;
  String? _username;
  List<String>? _interests;
  List<String>? _photoUrls;
  dynamic _profileImage; // Store profile image file (File or XFile)
  Map<String, dynamic>? _additionalData;

  /// Store email and password (called from signup email screen)
  void setEmailAndPassword(String email, String password) {
    _email = email;
    _password = password;
    
    if (kDebugMode) {
      print('Signup data stored: email=$email');
    }
  }

  /// Store phone number (called from OTP screen after verification)
  void setPhoneNumber(String phoneNumber) {
    _phoneNumber = phoneNumber;
    
    if (kDebugMode) {
      print('Phone number stored: $phoneNumber');
    }
  }

  /// Store display name (called from name screen)
  void setDisplayName(String displayName) {
    _displayName = displayName;
    
    if (kDebugMode) {
      print('Display name stored: $displayName');
    }
  }

  /// Store username (called from username screen if exists)
  void setUsername(String username) {
    _username = username;
    
    if (kDebugMode) {
      print('Username stored: $username');
    }
  }

  /// Store interests (called from interest screen)
  void setInterests(List<String> interests) {
    _interests = interests;
    
    if (kDebugMode) {
      print('Interests stored: ${interests.length} items');
    }
  }

  /// Store photo URLs (called from upload photos screen)
  void setPhotoUrls(List<String> photoUrls) {
    _photoUrls = photoUrls;
    
    if (kDebugMode) {
      print('Photo URLs stored: ${photoUrls.length} items');
    }
  }

  /// Store profile image (called from upload photos screen)
  void setProfileImage(dynamic image) {
    _profileImage = image;
    
    if (kDebugMode) {
      print('Profile image stored: ${image != null ? 'image selected' : 'no image'}');
    }
  }

  /// Store additional data
  void setAdditionalData(Map<String, dynamic> data) {
    _additionalData = data;
  }

  /// Get stored email
  String? get email => _email;

  /// Get stored password
  String? get password => _password;

  /// Get stored phone number
  String? get phoneNumber => _phoneNumber;

  /// Get stored display name
  String? get displayName => _displayName;

  /// Get stored username
  String? get username => _username;

  /// Get stored interests
  List<String>? get interests => _interests;

  /// Get stored photo URLs
  List<String>? get photoUrls => _photoUrls;

  /// Get stored profile image
  dynamic get profileImage => _profileImage;

  /// Get all additional data
  Map<String, dynamic>? get additionalData => _additionalData;

  /// Check if email and password are stored
  bool get hasEmailAndPassword => _email != null && _password != null;

  /// Check if all required data is stored
  bool get hasAllRequiredData => 
      _email != null && 
      _password != null && 
      _displayName != null;

  /// Get all stored data as a map
  Map<String, dynamic> getAllData() {
    return {
      'email': _email,
      'password': _password,
      'phoneNumber': _phoneNumber,
      'displayName': _displayName,
      'username': _username,
      'interests': _interests,
      'photoUrls': _photoUrls,
      'profileImage': _profileImage != null ? 'image_selected' : null,
      if (_additionalData != null) ..._additionalData!,
    };
  }

  /// Clear all stored data (called after successful user creation)
  void clearAllData() {
    _email = null;
    _password = null;
    _phoneNumber = null;
    _displayName = null;
    _username = null;
    _interests = null;
    _photoUrls = null;
    _profileImage = null;
    _additionalData = null;
    
    if (kDebugMode) {
      print('All signup data cleared');
    }
  }

  /// Clear only email and password (for security)
  void clearCredentials() {
    _email = null;
    _password = null;
    
    if (kDebugMode) {
      print('Credentials cleared');
    }
  }
}

