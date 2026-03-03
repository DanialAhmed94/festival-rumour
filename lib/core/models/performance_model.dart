import '../api/api_config.dart';

/// Model for a single performance from the API (performance-all).
/// Matches crapadvisor Performance API response structure (same JSON keys, including typo technical_rquirement_*).
class PerformanceModel {
  final int id;
  final int festivalId;
  final int userId;
  final String? bandName;
  final String? artistName;
  final String? performanceTitle;
  final String? technicalRequirementLighting;
  final String? technicalRequirementSound;
  final String? technicalRequirementStageSetup;
  final String? technicalRequirementSpecialNotes;
  final String? transitionDetail;
  final String? participantName;
  final String? specialGuests;
  final String? startTime;
  final String? endTime;
  final String? startDate;
  final String? endDate;
  final String? image;
  final String? createdAt;
  final String? updatedAt;
  /// Raw festival object from API (same as crapadvisor Performance.festival).
  final Map<String, dynamic>? festival;
  /// Raw event object from API (same as crapadvisor Performance.event).
  final Map<String, dynamic>? event;
  /// Derived from festival for convenience.
  final String? festivalName;
  /// Derived from event for convenience.
  final String? eventTitle;

  PerformanceModel({
    required this.id,
    required this.festivalId,
    required this.userId,
    this.bandName,
    this.artistName,
    this.performanceTitle,
    this.technicalRequirementLighting,
    this.technicalRequirementSound,
    this.technicalRequirementStageSetup,
    this.technicalRequirementSpecialNotes,
    this.transitionDetail,
    this.participantName,
    this.specialGuests,
    this.startTime,
    this.endTime,
    this.startDate,
    this.endDate,
    this.image,
    this.createdAt,
    this.updatedAt,
    this.festival,
    this.event,
    this.festivalName,
    this.eventTitle,
  });

  /// Parse from API JSON using same keys as crapadvisor Performance.fromJson.
  factory PerformanceModel.fromApiJson(Map<String, dynamic> json) {
    Map<String, dynamic>? festivalMap;
    String? festivalName;
    final festival = json['festival'];
    if (festival is Map<String, dynamic>) {
      festivalMap = festival;
      festivalName = festival['name_organizer']?.toString() ??
          festival['description_organizer']?.toString() ??
          festival['description']?.toString();
    }

    Map<String, dynamic>? eventMap;
    String? eventTitle;
    final event = json['event'];
    if (event is Map<String, dynamic>) {
      eventMap = event;
      eventTitle = event['event_title']?.toString();
    }

    return PerformanceModel(
      id: json['id'] as int? ?? 0,
      festivalId: json['festival_id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      bandName: json['band_name']?.toString(),
      artistName: json['artist_name']?.toString(),
      performanceTitle: json['performance_title']?.toString(),
      technicalRequirementLighting: json['technical_rquirement_lightening']?.toString(),
      technicalRequirementSound: json['technical_rquirement_sound']?.toString(),
      technicalRequirementStageSetup: json['technical_rquirement_stage_setup']?.toString(),
      technicalRequirementSpecialNotes: json['technical_rquirement_special_notes']?.toString(),
      transitionDetail: json['transition_detail']?.toString(),
      participantName: json['participant_name']?.toString(),
      specialGuests: json['special_guests']?.toString(),
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      image: json['image']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      festival: festivalMap,
      event: eventMap,
      festivalName: festivalName,
      eventTitle: eventTitle,
    );
  }

  String get imageUrl => ApiConfig.getPerformanceImageUrl(image);
}
