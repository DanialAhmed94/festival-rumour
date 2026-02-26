import 'dart:io';
import 'package:festival_rumour/core/constants/app_colors.dart';
import 'package:festival_rumour/core/constants/app_strings.dart';
import 'package:festival_rumour/core/di/locator.dart';
import 'package:festival_rumour/core/services/auth_service.dart';
import 'package:festival_rumour/core/services/firestore_service.dart';
import 'package:festival_rumour/core/utils/location_permission_helper.dart';
import 'package:festival_rumour/core/utils/location_utils.dart';
import 'package:festival_rumour/shared/widgets/responsive_text_widget.dart';
import 'package:festival_rumour/core/utils/snackbar_util.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../festival/festival_model.dart';

/// Bottom sheet for "Mark as attended festival": photo + location, with lazy loading
/// and background validation. Performance-oriented: minimal rebuilds, async validation.
class MarkAttendedSheet extends StatefulWidget {
  final FestivalModel festival;
  final VoidCallback? onSuccess;

  const MarkAttendedSheet({
    super.key,
    required this.festival,
    this.onSuccess,
  });

  @override
  State<MarkAttendedSheet> createState() => _MarkAttendedSheetState();
}

class _MarkAttendedSheetState extends State<MarkAttendedSheet> {
  final AuthService _auth = locator<AuthService>();
  final FirestoreService _firestore = locator<FirestoreService>();
  final ImagePicker _picker = ImagePicker();

  File? _photoFile;
  double? _lat;
  double? _lng;
  bool _isLoadingLocation = false;
  bool _isLoadingPhoto = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _canSubmit =>
      _photoFile != null && _lat != null && _lng != null && !_isSubmitting;

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildPhotoSourceSheet(ctx),
    );
    if (source == null || !mounted) return;
    setState(() => _isLoadingPhoto = true);
    try {
      final XFile? x = await _picker.pickImage(source: source, imageQuality: 50);
      if (mounted) {
        setState(() {
          _isLoadingPhoto = false;
          if (x != null) {
            _photoFile = File(x.path);
            _errorMessage = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPhoto = false;
          _errorMessage = 'Failed to pick image';
        });
        SnackbarUtil.showErrorSnackBar(context, 'Failed to pick image');
      }
    }
  }

  Widget _buildPhotoSourceSheet(BuildContext ctx) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.screenBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grey400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Choose photo source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Take a new photo or select from your gallery',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.grey600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.grey200,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.grey300),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.camera_alt_rounded, size: 28, color: AppColors.black),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Camera',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Take a new photo',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.grey600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.grey500),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.grey200,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.grey300),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.photo_library_rounded, size: 28, color: AppColors.black),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gallery',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Choose from your photos',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.grey600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.grey500),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 8 + MediaQuery.of(ctx).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _getLocation() async {
    if (_isLoadingLocation) return;
    setState(() {
      _isLoadingLocation = true;
      _errorMessage = null;
    });
    try {
      final result = await LocationPermissionHelper.requestLocationPermission(context);
      if (!mounted) return;
      if (result != LocationPermissionResult.granted) {
        setState(() {
          _isLoadingLocation = false;
          _errorMessage = 'Location permission denied';
        });
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _lat = position.latitude;
          _lng = position.longitude;
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _errorMessage = 'Could not get location';
        });
        SnackbarUtil.showErrorSnackBar(context, 'Could not get location');
      }
    }
  }

  Future<String> _uploadPhoto() async {
    final uid = _auth.userUid ?? _auth.currentUser?.uid;
    if (uid == null || _photoFile == null) throw Exception('No user or photo');
    final ref = FirebaseStorage.instance
        .ref()
        .child('attended_festivals')
        .child(uid)
        .child('${widget.festival.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    final task = ref.putFile(
      _photoFile!,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final snapshot = await task;
    return await snapshot.ref.getDownloadURL();
  }

  bool _validateLocationInBackground() {
    final festLat = widget.festival.latitude;
    final festLng = widget.festival.longitude;
    if (festLat == null ||
        festLng == null ||
        festLat.isEmpty ||
        festLng.isEmpty) {
      return true; // no venue location → allow
    }
    final festLatD = double.tryParse(festLat);
    final festLngD = double.tryParse(festLng);
    if (festLatD == null || festLngD == null) return true;
    return isWithinRadius(
      festLatD,
      festLngD,
      _lat!,
      _lng!,
      defaultFestivalRadiusMeters,
    );
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      // Background validation: location radius
      final withinRadius = _validateLocationInBackground();
      if (!withinRadius) {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
            _errorMessage = AppStrings.markAttendedLocationTooFar;
          });
          SnackbarUtil.showErrorSnackBar(
            context,
            AppStrings.markAttendedLocationTooFar,
          );
        }
        return;
      }
      if (mounted) {
        setState(() => _errorMessage = null);
      }
      final uid = _auth.userUid ?? _auth.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          SnackbarUtil.showErrorSnackBar(context, 'Please sign in to continue');
        }
        return;
      }
      final imageUrl = await _uploadPhoto();
      await _firestore.saveAttendedFestival(
        userId: uid,
        festivalId: widget.festival.id,
        festivalTitle: widget.festival.title,
        imageUrl: imageUrl,
        lat: _lat!,
        lng: _lng!,
      );
      if (!mounted) return;
      widget.onSuccess?.call();
      SnackbarUtil.showSuccessSnackBar(context, AppStrings.markAttendedSuccess);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
        });
        SnackbarUtil.showErrorSnackBar(
          context,
          'Something went wrong. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ResponsiveTextWidget(
              '${AppStrings.markAttendedTitle} – ${widget.festival.title}',
              textType: TextType.title,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 20),
          // Photo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: InkWell(
              onTap: (_isSubmitting || _isLoadingPhoto) ? null : _pickPhoto,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.grey400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    if (_isLoadingPhoto)
                      const SizedBox(
                        width: 56,
                        height: 56,
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.black,
                            ),
                          ),
                        ),
                      )
                    else if (_photoFile != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _photoFile!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Icon(Icons.add_a_photo, size: 40, color: AppColors.grey600),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ResponsiveTextWidget(
                            AppStrings.markAttendedAddPhoto,
                            textType: TextType.body,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.black,
                          ),
                          const SizedBox(height: 2),
                          ResponsiveTextWidget(
                            AppStrings.markAttendedAddPhotoHint,
                            textType: TextType.caption,
                            fontSize: 12,
                            color: AppColors.grey600,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Location
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: InkWell(
              onTap: _isSubmitting || _isLoadingLocation ? null : _getLocation,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.grey400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    if (_isLoadingLocation)
                      const SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.black,
                            ),
                          ),
                        ),
                      )
                    else if (_lat != null && _lng != null)
                      Icon(Icons.location_on, size: 40, color: AppColors.accent)
                    else
                      Icon(Icons.location_off, size: 40, color: AppColors.grey600),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ResponsiveTextWidget(
                            AppStrings.markAttendedGetLocation,
                            textType: TextType.body,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.black,
                          ),
                          const SizedBox(height: 2),
                          ResponsiveTextWidget(
                            _lat != null
                                ? '${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}'
                                : AppStrings.markAttendedLocationHint,
                            textType: TextType.caption,
                            fontSize: 12,
                            color: AppColors.grey600,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.red,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.black,
                        ),
                      )
                    : const Text(AppStrings.markAttendedSubmit),
              ),
            ),
          ),
          SizedBox(height: 20 + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
