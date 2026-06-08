class StreamUrl {
  final String url;
  final String format; // 'hls', 'dash', 'mp3'

  StreamUrl({required this.url, required this.format});

  factory StreamUrl.fromJson(Map<String, dynamic> json) {
    return StreamUrl(
      url: json['url'] as String,
      format: json['format'] as String,
    );
  }
}

class BroadcastSchedule {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String hostName;
  final String category;
  final String? thumbnailUrl;

  BroadcastSchedule({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.hostName,
    required this.category,
    this.thumbnailUrl,
  });

  factory BroadcastSchedule.fromJson(Map<String, dynamic> json) {
    return BroadcastSchedule(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      hostName: json['host_name'] as String,
      category: json['category'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
    );
  }
}

class Recording {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final String? thumbnailUrl;
  final int durationSeconds;
  final String category;
  final DateTime createdAt;

  Recording({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.durationSeconds,
    required this.category,
    required this.createdAt,
  });

  factory Recording.fromJson(Map<String, dynamic> json) {
    return Recording(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      videoUrl: json['video_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      durationSeconds: json['duration_seconds'] as int,
      category: json['category'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class RadioShow {
  final String id;
  final String title;
  final String description;
  final String hostName;
  final DateTime startTime;
  final DateTime endTime;
  final String? streamUrl;
  final bool isLive;

  RadioShow({
    required this.id,
    required this.title,
    required this.description,
    required this.hostName,
    required this.startTime,
    required this.endTime,
    this.streamUrl,
    required this.isLive,
  });

  factory RadioShow.fromJson(Map<String, dynamic> json) {
    return RadioShow(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      hostName: json['host_name'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      streamUrl: json['stream_url'] as String?,
      isLive: json['is_live'] as bool,
    );
  }
}
