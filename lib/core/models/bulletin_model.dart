/// Model for a single news bulletin from the API.
class BulletinModel {
  final int id;
  final String? title;
  final String? content;
  final int? userId;
  final String? publishNow;
  final String? date;
  final String? time;
  final String? createdAt;
  final String? updatedAt;

  BulletinModel({
    required this.id,
    this.title,
    this.content,
    this.userId,
    this.publishNow,
    this.date,
    this.time,
    this.createdAt,
    this.updatedAt,
  });

  /// Create from API response item (snake_case keys).
  factory BulletinModel.fromApiJson(Map<String, dynamic> json) {
    return BulletinModel(
      id: json['id'] as int? ?? 0,
      title: json['title']?.toString(),
      content: json['content']?.toString(),
      userId: json['user_id'] as int?,
      publishNow: json['publish_now']?.toString(),
      date: json['date']?.toString(),
      time: json['time']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}
