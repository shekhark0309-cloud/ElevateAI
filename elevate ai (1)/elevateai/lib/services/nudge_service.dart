import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/nudge_model.dart';
import 'dna_service.dart';
import 'trust_score_service.dart';
import 'opportunity_service.dart';
import 'campus_service.dart';
import 'notification_service.dart';

class NudgeService {
  final _supabase = Supabase.instance.client;
  final _dnaService = DNAService();
  final _trustService = TrustScoreService();
  final _oppService = OpportunityService();
  final _campusService = CampusService();
  final _notifService = NotificationService();

  Future<List<SmartNudge>> generateSmartNudges(String studentId) async {
    List<SmartNudge> nudges = [];

    try {
      // 1. Fetch data for context
      final profileData = await _supabase.from('student_profiles').select().eq('id', studentId).single();
      final collegeId = profileData['college_id'];

      // 2. TrustScore Nudge (Actionable)
      final trust = await _trustService.getMyScore(studentId);
      if (trust.overallScore > 8.0) {
        final nudge = SmartNudge.fromType(
          id: 'trust-high',
          title: 'High TrustScore!',
          body: 'Your TrustScore is ${trust.overallScore.toStringAsFixed(1)}. You are now eligible for elite team matches.',
          type: NudgeType.trust,
          route: '/team_finder',
          actionLabel: 'Find Teams',
        );
        nudges.add(nudge);
      }

      // 3. DNA / Skill Gaps Nudge (Contextual)
      final gaps = await _dnaService.getCareerGaps(studentId);
      if (gaps['missing_skills'] != null && (gaps['missing_skills'] as List).isNotEmpty) {
        final skill = (gaps['missing_skills'] as List).first;
        final nudge = SmartNudge.fromType(
          id: 'dna-skill-gap',
          title: 'Skill Recommendation',
          body: 'You are missing $skill for your target role. Start a learning path today.',
          type: NudgeType.career,
          route: '/skill_reality',
          actionLabel: 'Learn $skill',
        );
        nudges.add(nudge);
      }

      // 4. Study Buddy Nudge (Real-time/Nearby)
      if (collegeId != null) {
        final buddies = await _campusService.getStudyBuddies(collegeId: collegeId);
        if (buddies.isNotEmpty) {
          final count = buddies.length;
          final subject = buddies.first.currentStudySubject ?? 'Subjects';
          final nudge = SmartNudge.fromType(
            id: 'buddy-nearby',
            title: 'Study Buddies Nearby',
            body: '$count students are studying nearby. Join them for a $subject session.',
            type: NudgeType.buddy,
            route: '/campus_connect',
            actionLabel: 'View Map',
          );
          nudges.add(nudge);

          // Push as notification if buddy is studying the same subject
          await _notifService.createSmartNudgeNotification(
            studentId: studentId,
            title: nudge.title,
            body: nudge.body,
            type: 'buddy_context',
          );
        }
      }

      // 5. Opportunity / Scholarship Deadline Nudge (Priority)
      final ranked = await _oppService.getRankedOpportunities(studentId: studentId, typeFilter: ['scholarship', 'hackathon']);
      final matches = ranked['data']?['matches'] as List? ?? [];
      if (matches.isNotEmpty) {
        final top = matches.first;
        final deadlineString = top['apply_deadline'];
        if (deadlineString != null) {
          final deadline = DateTime.parse(deadlineString);
          final daysLeft = deadline.difference(DateTime.now()).inDays;

          if (daysLeft <= 3 && daysLeft >= 0) {
            final nudge = SmartNudge.fromType(
              id: 'opp-deadline',
              title: 'Approaching Deadline',
              body: '${top['title']} ends in $daysLeft days. Apply now to secure your spot.',
              type: NudgeType.opportunity,
              route: '/opportunities',
              actionLabel: 'Apply Now',
            );
            nudges.add(nudge);

            // Priority notification for deadlines
            await _notifService.createSmartNudgeNotification(
              studentId: studentId,
              title: 'URGENT: ${nudge.title}',
              body: nudge.body,
              type: 'priority_reminder',
            );
          }
        }
      }

      // 6. FocusAI / Study Session Nudge (Smart Reminder)
      final dna = await _supabase.from('student_dna').select().eq('student_id', studentId).maybeSingle();
      if (dna != null) {
        final streak = dna['study_streak'] ?? 0;
        if (streak > 0) {
          nudges.add(SmartNudge.fromType(
            id: 'focus-streak',
            title: 'Keep it up!',
            body: 'You are on a $streak day study streak. Start today\'s session to maintain it.',
            type: NudgeType.focus,
            route: '/focus',
            actionLabel: 'Start Session',
          ));
        }
      }

    } catch (e) {
      print('Error generating nudges: $e');
    }

    return nudges;
  }
}
