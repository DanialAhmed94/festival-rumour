import '../../../core/api/api_config.dart';

enum FestivalStatus { past, live, upcoming }

class FestivalModel {
  final int id;
  final String title;
  final String location;
  final String date;
  final String imagepath;
  final bool isLive;
  final FestivalStatus status; // Status: past, live, or upcoming
  final String? description;
  final String? descriptionOrganizer;
  final String? nameOrganizer;
  final String? latitude;
  final String? longitude;
  final String? time;
  final String? price;
  final String? startingDate;
  final String? endingDate;

  FestivalModel({
    required this.id,
    required this.title,
    required this.location,
    required this.date,
    required this.imagepath,
    this.isLive = false,
    required this.status,
    this.description,
    this.descriptionOrganizer,
    this.nameOrganizer,
    this.latitude,
    this.longitude,
    this.time,
    this.price,
    this.startingDate,
    this.endingDate,
  });

  /// Create FestivalModel from API response
  factory FestivalModel.fromApiJson(Map<String, dynamic> json) {
    // Determine title - use description, but if it's "N/A", use name_organizer
    final description = json['description']?.toString() ?? '';
    final nameOrganizer = json['name_organizer']?.toString() ?? '';

    String title;
    if (description.isNotEmpty && description.toUpperCase() != 'N/A') {
      title = description;
    } else if (nameOrganizer.isNotEmpty) {
      title = nameOrganizer;
    } else {
      title = 'Festival';
    }

    // Determine location - use latitude/longitude or default
    final lat = json['latitude']?.toString();
    final lng = json['longitude']?.toString();
    final location =
        (lat != null && lng != null) ? '$lat, $lng' : 'Location TBD';

    // Format date - use starting_date and ending_date
    final startingDate = json['starting_date']?.toString() ?? '';
    final endingDate = json['ending_date']?.toString() ?? '';
    String date;
    if (startingDate.isNotEmpty && endingDate.isNotEmpty) {
      if (startingDate == endingDate) {
        date = _formatDate(startingDate);
      } else {
        date = '${_formatDate(startingDate)} - ${_formatDate(endingDate)}';
      }
    } else if (startingDate.isNotEmpty) {
      date = _formatDate(startingDate);
    } else {
      date = 'Date TBD';
    }

    // Get image path and convert to full URL
    final imagePath = json['image']?.toString() ?? '';
    final imageUrl =
        imagePath.isNotEmpty ? ApiConfig.getImageUrl(imagePath) : '';

    // Determine festival status: past, live, or upcoming
    final status = _getFestivalStatus(startingDate, endingDate);

    // Determine if festival is live (currently happening)
    final isLive = status == FestivalStatus.live;

    return FestivalModel(
      id: json['id'] as int? ?? 0,
      title: title,
      location: location,
      date: date,
      imagepath: imageUrl,
      isLive: isLive,
      status: status,
      description: json['description']?.toString(),
      descriptionOrganizer: json['description_organizer']?.toString(),
      nameOrganizer: json['name_organizer']?.toString(),
      latitude: lat,
      longitude: lng,
      time: json['time']?.toString(),
      price: json['price']?.toString(),
      startingDate: startingDate,
      endingDate: endingDate,
    );
  }

  /// Format date from API format (YYYY-MM-DD) to readable format
  static String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  /// Determine festival status: past, live, or upcoming
  static FestivalStatus _getFestivalStatus(
    String? startingDate,
    String? endingDate,
  ) {
    if (startingDate == null ||
        endingDate == null ||
        startingDate.isEmpty ||
        endingDate.isEmpty) {
      return FestivalStatus
          .upcoming; // Default to upcoming if dates are missing
    }

    try {
      final start = DateTime.parse(startingDate);
      final end = DateTime.parse(endingDate);
      final now = DateTime.now();

      // Normalize dates to compare only dates (ignore time)
      final startDate = DateTime(start.year, start.month, start.day);
      final endDate = DateTime(end.year, end.month, end.day);
      final currentDate = DateTime(now.year, now.month, now.day);

      // Past: if ending date has passed
      if (endDate.isBefore(currentDate)) {
        return FestivalStatus.past;
      }

      // Live: if current date is between start and end (inclusive)
      // Or if start date matches current date
      if ((currentDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
              currentDate.isBefore(endDate.add(const Duration(days: 1)))) ||
          startDate.isAtSameMomentAs(currentDate)) {
        return FestivalStatus.live;
      }

      // Upcoming: if start date is in the future
      if (startDate.isAfter(currentDate)) {
        return FestivalStatus.upcoming;
      }

      // Default to live if dates match exactly
      return FestivalStatus.live;
    } catch (e) {
      return FestivalStatus.upcoming; // Default to upcoming on error
    }
  }

  /// Check if festival is currently live (happening now)
  static bool _isFestivalLive(String? startingDate, String? endingDate) {
    return _getFestivalStatus(startingDate, endingDate) == FestivalStatus.live;
  }

  /// Create a copy of this model with updated fields
  FestivalModel copyWith({
    int? id,
    String? title,
    String? location,
    String? date,
    String? imagepath,
    bool? isLive,
    FestivalStatus? status,
    String? description,
    String? descriptionOrganizer,
    String? nameOrganizer,
    String? latitude,
    String? longitude,
    String? time,
    String? price,
    String? startingDate,
    String? endingDate,
  }) {
    return FestivalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      location: location ?? this.location,
      date: date ?? this.date,
      imagepath: imagepath ?? this.imagepath,
      isLive: isLive ?? this.isLive,
      status: status ?? this.status,
      description: description ?? this.description,
      descriptionOrganizer: descriptionOrganizer ?? this.descriptionOrganizer,
      nameOrganizer: nameOrganizer ?? this.nameOrganizer,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      time: time ?? this.time,
      price: price ?? this.price,
      startingDate: startingDate ?? this.startingDate,
      endingDate: endingDate ?? this.endingDate,
    );
  }
}
