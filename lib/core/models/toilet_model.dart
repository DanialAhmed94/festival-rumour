import '../api/api_config.dart';

/// Model for a single toilet from the API (toilets-all).
/// API returns items with nested festival and toilet_types.
class ToiletModel {
  final int id;
  final int? userId;
  final int festivalId;
  final int? toiletTypeId;
  final String? latitude;
  final String? longitude;
  final String? what3Words;
  final String? image;
  final String? createdAt;
  final String? updatedAt;
  /// Toilet type name (from nested toilet_types)
  final String toiletTypeName;
  /// Toilet type image URL (from nested toilet_types)
  final String toiletTypeImageUrl;
  /// Festival name for display (from nested festival)
  final String? festivalName;

  ToiletModel({
    required this.id,
    this.userId,
    required this.festivalId,
    this.toiletTypeId,
    this.latitude,
    this.longitude,
    this.what3Words,
    this.image,
    this.createdAt,
    this.updatedAt,
    required this.toiletTypeName,
    required this.toiletTypeImageUrl,
    this.festivalName,
  });

  /// Create from API response item. Handles nested festival and toilet_types.
  factory ToiletModel.fromApiJson(Map<String, dynamic> json) {
    String typeName = '';
    String typeImageUrl = '';
    final toiletTypes = json['toilet_types'];
    if (toiletTypes is Map<String, dynamic>) {
      typeName = toiletTypes['name']?.toString() ?? '';
      final img = toiletTypes['image']?.toString();
      typeImageUrl = ApiConfig.getToiletTypeImageUrl(img);
    }

    String? festivalName;
    final festival = json['festival'];
    if (festival is Map<String, dynamic>) {
      festivalName = festival['name_organizer']?.toString() ??
          festival['description']?.toString();
    }

    return ToiletModel(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int?,
      festivalId: json['festival_id'] as int? ?? 0,
      toiletTypeId: json['toilet_type_id'] as int?,
      latitude: json['latitude']?.toString(),
      longitude: json['longitude']?.toString(),
      what3Words: json['what_3_words']?.toString(),
      image: json['image']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      toiletTypeName: typeName.isEmpty ? 'Toilet' : typeName,
      toiletTypeImageUrl: typeImageUrl,
      festivalName: festivalName,
    );
  }

  /// Full URL for this toilet's image (if any)
  String get imageUrl {
    if (image == null || image!.isEmpty) return '';
    return ApiConfig.getToiletImageUrl(image);
  }
}
