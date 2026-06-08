import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../flutter_integration.dart';
import '../widgets/loading_skeleton.dart';
import '../services/resume_pdf_generator.dart';
import '../services/portfolio_service.dart';
import 'dart:io';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final _skillsService = SkillsService();
  final _portfolioService = PortfolioService();
  bool _isLoading = true;
  bool _isGeneratingPdf = false;
  String? _errorMessage;
  Map<String, dynamic>? _portfolio;
  Map<String, dynamic>? _profileData;
  ResumeTemplate _selectedTemplate = ResumeTemplate.classic;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not authenticated");

      final profileRes = await supabase
          .from('student_profiles')
          .select()
          .eq('id', user.id)
          .single();
      _profileData = profileRes;

      final res = await _skillsService.generatePortfolio();
      if (mounted) {
        setState(() {
          _portfolio = res['resume'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dynamic Portfolio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              if (_portfolio == null) return;
              final user = supabase.auth.currentUser;
              final skills = (_portfolio!['skills'] as List? ?? []).take(3).join(', ');

              Share.share(
                "Check out my ElevateAI portfolio! 🚀\n"
                "Top Skills: $skills\n"
                "View full portfolio: io.supabase.elevateai://portfolio/${user?.id}"
              );
            },
          ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _buildPortfolioContent(),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoadingSkeleton(height: 30, width: 200),
          const SizedBox(height: 16),
          LoadingSkeleton(height: 100, width: double.infinity),
          const SizedBox(height: 24),
          LoadingSkeleton(height: 30, width: 150),
          const SizedBox(height: 16),
          LoadingSkeleton(height: 200, width: double.infinity),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(child: Text(_errorMessage!));
  }

  Widget _buildPortfolioContent() {
    if (_portfolio == null) return const Center(child: Text('No data found'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTemplatePicker(),
          const SizedBox(height: 24),
          _section('SUMMARY', _portfolio!['summary']),
          const SizedBox(height: 24),
          const Text('SKILLS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: (_portfolio!['skills'] as List? ?? []).map((s) => Chip(label: Text(s))).toList(),
          ),
          const SizedBox(height: 24),
          _listSection('EXPERIENCE', _portfolio!['experience']),
          const SizedBox(height: 24),
          _listSection('PROJECTS', _portfolio!['projects']),
          const SizedBox(height: 24),
          _educationSection('EDUCATION', _portfolio!['education']),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: _isGeneratingPdf ? null : _generateAndExportPdf,
              icon: _isGeneratingPdf
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf),
              label: Text(_isGeneratingPdf ? 'Generating PDF...' : 'Generate & Export PDF Resume'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: _showHistory,
              icon: const Icon(Icons.history),
              label: const Text('View Resume History'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CHOOSE TEMPLATE',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12, letterSpacing: 1.1)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ResumeTemplate.values.map((t) {
              final isSelected = _selectedTemplate == t;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(t.name.toUpperCase()),
                  selected: isSelected,
                  onSelected: (val) => setState(() => _selectedTemplate = t),
                  selectedColor: Colors.indigo.shade100,
                  labelStyle: TextStyle(
                      color: isSelected ? Colors.indigo : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _generateAndExportPdf() async {
    if (_portfolio == null || _profileData == null) return;
    setState(() => _isGeneratingPdf = true);

    try {
      final user = supabase.auth.currentUser;
      final pdfFile = await ResumePdfGenerator.generateResumePdf(
        _portfolio!,
        _profileData!,
        template: _selectedTemplate,
      );

      // Upload to Supabase for storage/history
      final publicUrl = await _portfolioService.uploadResume(
        user!.id,
        pdfFile,
        _portfolio!,
        template: _selectedTemplate.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resume generated and saved!')));

        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfFile.readAsBytes(),
          name: 'ElevateAI_Resume_${user.id.substring(0, 5)}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  void _showHistory() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _portfolioService.getResumeHistory(user.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final history = snapshot.data ?? [];
          if (history.isEmpty) {
            return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No history found.')));
          }

          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              return ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text('Version ${history.length - index}'),
                subtitle: Text('Generated: ${item['created_at'].toString().substring(0, 16)}'),
                trailing: const Icon(Icons.download),
                onTap: () => launchUrl(Uri.parse(item['pdf_url'])),
              );
            },
          );
        },
      ),
    );
  }

  Widget _section(String title, String? content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 12),
        Text(content ?? '', style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget _listSection(String title, dynamic list) {
    final items = list as List? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 12),
        ...items.map((i) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(i['title'] ?? i['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (i['duration'] != null) Text(i['duration'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  Text(i['org'] ?? i['tech'] ?? '', style: const TextStyle(color: Colors.indigo)),
                  if (i['bullets'] != null)
                    ...(i['bullets'] as List).map((b) => Text('• $b', style: const TextStyle(fontSize: 14))),
                  if (i['impact'] != null) Text(i['impact'], style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
                ],
              ),
            )),
      ],
    );
  }

  Widget _educationSection(String title, dynamic edu) {
    if (edu == null) return Container();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 12),
        Text(edu['degree'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(edu['institution'] ?? ''),
        Text('CGPA: ${edu['cgpa']} • Year: ${edu['year']}'),
      ],
    );
  }
}
