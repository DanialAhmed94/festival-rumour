import '../api/api_config.dart';

/// Model for a single event from the API (events-all).
/// Matches crapadvisor EventData API response structure.
class EventModel {
  final int id;
  final int festivalId;
  final int userId;
  final String? eventTitle;
  final String? eventDescription;
  final String? grandTotal;
  final String? taxPercentage;
  final String? pricePerPerson;
  final String? crowdCapacity;
  final String? startTime;
  final String? startDate;
  final String? endTime;
  final String? image;
  final String? createdAt;
  final String? updatedAt;
  /// Raw festival object from API (same as crapadvisor EventData.festival).
  final Map<String, dynamic>? festival;
  /// Derived from festival for convenience.
  final String? festivalName;

  EventModel({
    required this.id,
    required this.festivalId,
    required this.userId,
    this.eventTitle,
    this.eventDescription,
    this.grandTotal,
    this.taxPercentage,
    this.pricePerPerson,
    this.crowdCapacity,
    this.startTime,
    this.startDate,
    this.endTime,
    this.image,
    this.createdAt,
    this.updatedAt,
    this.festival,
    this.festivalName,
  });

  /// Parse from API JSON using same keys as crapadvisor EventData.fromJson.
  factory EventModel.fromApiJson(Map<String, dynamic> json) {
    Map<String, dynamic>? festivalMap;
    String? festivalName;
    final festival = json['festival'];
    if (festival is Map<String, dynamic>) {
      festivalMap = festival;
      festivalName = festival['name_organizer']?.toString() ??
          festival['description_organizer']?.toString() ??
          festival['description']?.toString();
    }

    return EventModel(
      id: json['id'] as int? ?? 0,
      festivalId: json['festival_id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      eventTitle: json['event_title']?.toString(),
      eventDescription: json['event_description']?.toString(),
      grandTotal: json['grand_total']?.toString(),
      taxPercentage: json['tax_percentage']?.toString(),
      pricePerPerson: json['price_per_person']?.toString(),
      crowdCapacity: json['crowd_capacity']?.toString(),
      startTime: json['start_time']?.toString(),
      startDate: json['start_date']?.toString(),
      endTime: json['end_time']?.toString(),
      image: json['image']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      festival: festivalMap,
      festivalName: festivalName,
    );
  }

  String get imageUrl => ApiConfig.getEventImageUrl(image);
}
