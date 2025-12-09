import 'package:flutter/foundation.dart';

class PhoneAuthService {
  static final PhoneAuthService _instance = PhoneAuthService._internal();
  factory PhoneAuthService() => _instance;
  PhoneAuthService._internal();

  String? _phoneNumber;
  String? _verificationId;

  String? get phoneNumber => _phoneNumber;
  String? get verificationId => _verificationId;

  void setPhoneData(String phoneNumber, String verificationId) {
    _phoneNumber = phoneNumber;
    // Store verification ID - empty string is allowed initially (before code is sent)
    // but should be replaced with actual ID when codeSent callback fires
    _verificationId = verificationId.isEmpty ? null : verificationId;
    
    if (kDebugMode) {
      print('📞 [PhoneAuthService] Phone data stored');
      print('   Phone Number: $phoneNumber');
      if (verificationId.isEmpty) {
        print('   Verification ID: EMPTY (will be set when code is sent)');
      } else {
        print('   Verification ID: ${verificationId.length > 20 ? "${verificationId.substring(0, 20)}..." : verificationId}');
      }
      print('   Has valid data: ${hasPhoneData}');
    }
  }

  void clearPhoneData() {
    _phoneNumber = null;
    _verificationId = null;
    
    if (kDebugMode) {
      print('Phone data cleared');
    }
  }

  bool get hasPhoneData => _phoneNumber != null && _verificationId != null;
}
