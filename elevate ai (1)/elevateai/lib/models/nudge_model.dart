import 'package:flutter/material.dart';

enum NudgeType {
  study,
  career,
  scholarship,
  hackathon,
  team,
  opportunity,
  focus,
  campus,
  buddy,
  portfolio,
  trust
}

class SmartNudge {
  final String id;
  final String title;
  final String body;
  final NudgeType type;
  final String? route;
  final String? actionLabel;
  final IconData icon;
  final Color color;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  SmartNudge({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.route,
    this.actionLabel,
    required this.icon,
    required this.color,
    required this.createdAt,
    this.metadata,
  });

  factory SmartNudge.fromType({
    required String id,
    required String title,
    required String body,
    required NudgeType type,
    String? route,
    String? actionLabel,
    Map<String, dynamic>? metadata,
  }) {
    IconData icon;
    Color color;

    switch (type) {
      case NudgeType.study:
        icon = Icons.book_outlined;
        color = Colors.blue;
        break;
      case NudgeType.career:
        icon = Icons.work_outline;
        color = Colors.indigo;
        break;
      case NudgeType.scholarship:
        icon = Icons.school_outlined;
        color = Colors.green;
        break;
      case NudgeType.hackathon:
        icon = Icons.code;
        color = Colors.purple;
        break;
      case NudgeType.team:
        icon = Icons.groups_outlined;
        color = Colors.orange;
        break;
      case NudgeType.opportunity:
        icon = Icons.explore_outlined;
        color = Colors.teal;
        break;
      case NudgeType.focus:
        icon = Icons.timer_outlined;
        color = Colors.red;
        break;
      case NudgeType.campus:
        icon = Icons.hub_outlined;
        color = Colors.blueGrey;
        break;
      case NudgeType.buddy:
        icon = Icons.person_search_outlined;
        color = Colors.pink;
        break;
      case NudgeType.portfolio:
        icon = Icons.badge_outlined;
        color = Colors.amber;
        break;
      case NudgeType.trust:
        icon = Icons.verified_user_outlined;
        color = Colors.amber;
        break;
    }

    return SmartNudge(
      id: id,
      title: title,
      body: body,
      type: type,
      route: route,
      actionLabel: actionLabel,
      icon: icon,
      color: color,
      createdAt: DateTime.now(),
      metadata: metadata,
    );
  }
}
