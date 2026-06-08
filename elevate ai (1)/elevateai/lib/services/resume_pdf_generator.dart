import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../flutter_integration.dart';

enum ResumeTemplate { classic, modern, technical, student }

class ResumePdfGenerator {
  static Future<File> generateResumePdf(
    Map<String, dynamic> resumeData,
    Map<String, dynamic> profile, {
    ResumeTemplate template = ResumeTemplate.classic,
  }) async {
    final pdf = pw.Document();

    final summary = resumeData['summary'] ?? '';
    final skills = List<String>.from(resumeData['skills'] ?? []);
    final experience = List<Map<String, dynamic>>.from(resumeData['experience'] ?? []);
    final projects = List<Map<String, dynamic>>.from(resumeData['projects'] ?? []);
    final education = resumeData['education'] ?? {};
    final achievements = List<Map<String, dynamic>>.from(resumeData['achievements'] ?? []);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
        build: (context) => [
          _buildHeader(profile, template),
          pw.SizedBox(height: 20),
          _buildSectionTitle('PROFESSIONAL SUMMARY', template),
          pw.Text(summary, style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.5)),
          pw.SizedBox(height: 20),
          _buildSectionTitle('TECHNICAL SKILLS', template),
          _buildSkills(skills, template),
          pw.SizedBox(height: 20),
          if (experience.isNotEmpty) ...[
            _buildSectionTitle('EXPERIENCE', template),
            ...experience.map((exp) => _buildExperienceItem(exp, template)),
            pw.SizedBox(height: 10),
          ],
          if (projects.isNotEmpty) ...[
            _buildSectionTitle('KEY PROJECTS', template),
            ...projects.map((proj) => _buildProjectItem(proj, template)),
            pw.SizedBox(height: 10),
          ],
          if (achievements.isNotEmpty) ...[
            _buildSectionTitle('ACHIEVEMENTS & AWARDS', template),
            ...achievements.map((ach) => _buildAchievementItem(ach, template)),
            pw.SizedBox(height: 10),
          ],
          _buildSectionTitle('EDUCATION', template),
          _buildEducation(education, template),
          pw.SizedBox(height: 30),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Generated via ElevateAI Portfolio Assistant',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic)),
          ),
        ],
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/resume_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _buildHeader(Map<String, dynamic> profile, ResumeTemplate template) {
    final primaryColor = _getPrimaryColor(template);

    return pw.Column(
      crossAxisAlignment: template == ResumeTemplate.modern ? pw.CrossAxisAlignment.center : pw.CrossAxisAlignment.start,
      children: [
        pw.Text(profile['full_name']?.toUpperCase() ?? 'STUDENT NAME',
            style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: primaryColor)),
        pw.SizedBox(height: 4),
        pw.Text('${profile['course']} | ${profile['branch']} | Year ${profile['year_of_study']}',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
        pw.SizedBox(height: 2),
        pw.Row(
          mainAxisAlignment: template == ResumeTemplate.modern ? pw.MainAxisAlignment.center : pw.MainAxisAlignment.start,
          children: [
            pw.Text('Email: ${profile['email']}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(width: 15),
            pw.Text('Phone: ${profile['phone'] ?? 'N/A'}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            if (profile['state'] != null) ...[
              pw.SizedBox(width: 15),
              pw.Text('Location: ${profile['state']}, India', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            ]
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildSectionTitle(String title, ResumeTemplate template) {
    final color = _getPrimaryColor(template);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color, letterSpacing: 1.2)),
        pw.SizedBox(height: 3),
        pw.Container(height: 1, color: color.luminance > 0.5 ? PdfColors.grey300 : color.withAlpha(100)),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _buildSkills(List<String> skills, ResumeTemplate template) {
    if (template == ResumeTemplate.technical) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: skills.map((s) => pw.Bullet(text: s, style: const pw.TextStyle(fontSize: 10))).toList(),
      );
    }
    return pw.Wrap(
      spacing: 6,
      runSpacing: 6,
      children: skills.map((s) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: pw.BoxDecoration(
          color: template == ResumeTemplate.modern ? PdfColors.blue50 : null,
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Text(s, style: const pw.TextStyle(fontSize: 9)),
      )).toList(),
    );
  }

  static pw.Widget _buildExperienceItem(Map<String, dynamic> exp, ResumeTemplate template) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(exp['title'] ?? '', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
              pw.Text(exp['duration'] ?? '', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            ],
          ),
          pw.Text(exp['org'] ?? '', style: pw.TextStyle(fontSize: 10, color: _getPrimaryColor(template), fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          ...((exp['bullets'] as List? ?? []).map((b) => pw.Padding(
            padding: const pw.EdgeInsets.only(left: 4, bottom: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('• ', style: const pw.TextStyle(fontSize: 10)),
                pw.Expanded(child: pw.Text(b, style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.2))),
              ],
            ),
          ))),
        ],
      ),
    );
  }

  static pw.Widget _buildProjectItem(Map<String, dynamic> proj, ResumeTemplate template) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(proj['name'] ?? '', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.Text('Tech Stack: ${proj['tech'] ?? ''}', style: const pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey800)),
          pw.SizedBox(height: 2),
          pw.Text(proj['impact'] ?? '', style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.2)),
        ],
      ),
    );
  }

  static pw.Widget _buildAchievementItem(Map<String, dynamic> ach, ResumeTemplate template) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('🏆 ', style: const pw.TextStyle(fontSize: 10)),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(ach['title'] ?? '', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                if (ach['issued_by'] != null)
                  pw.Text('Issued by: ${ach['issued_by']}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildEducation(Map<String, dynamic> edu, ResumeTemplate template) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(edu['degree'] ?? '', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.Text(edu['year']?.toString() ?? '', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ],
        ),
        pw.Text(edu['institution'] ?? '', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Performance: ${edu['cgpa']} CGPA', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
      ],
    );
  }

  static PdfColor _getPrimaryColor(ResumeTemplate template) {
    switch (template) {
      case ResumeTemplate.modern: return PdfColors.blue800;
      case ResumeTemplate.technical: return PdfColors.teal900;
      case ResumeTemplate.student: return PdfColors.indigo800;
      case ResumeTemplate.classic:
      default:
        return PdfColors.black;
    }
  }
}
