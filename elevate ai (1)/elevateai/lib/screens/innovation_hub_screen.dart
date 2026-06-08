import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../flutter_integration.dart';
import '../models/idea_models.dart';
import '../widgets/loading_skeleton.dart';

class InnovationHubScreen extends StatefulWidget {
  const InnovationHubScreen({super.key});

  @override
  State<InnovationHubScreen> createState() => _InnovationHubScreenState();
}

class _InnovationHubScreenState extends State<InnovationHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _innovationService = InnovationService();
  bool _isLoading = true;
  List<ProjectIdea> _feedIdeas = [];
  List<ProjectIdea> _recommendedIdeas = [];
  String _selectedCategory = 'All';

  final List<String> _categories = ['All', 'SaaS', 'Fintech', 'AI/ML', 'Hardware', 'Social', 'EdTech'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final feed = await _innovationService.getDiscoveryFeed(category: _selectedCategory);
        final recs = await _innovationService.getRecommendedIdeas(user.id);

        if (mounted) {
          setState(() {
            _feedIdeas = feed;
            _recommendedIdeas = recs;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Innovation Hub', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6200EE),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF6200EE),
          tabs: const [
            Tab(text: 'Discovery'),
            Tab(text: 'For You'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _showCreateIdeaSheet(),
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF6200EE)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDiscoveryTab(),
                _buildRecommendationsTab(),
              ],
            ),
    );
  }

  Widget _buildDiscoveryTab() {
    return Column(
      children: [
        _buildCategoryFilter(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _feedIdeas.length,
              itemBuilder: (context, index) => _ideaCard(_feedIdeas[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationsTab() {
    if (_recommendedIdeas.isEmpty) {
      return const Center(child: Text('No recommendations yet. Build your DNA!'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _recommendedIdeas.length,
      itemBuilder: (context, index) => _ideaCard(_recommendedIdeas[index], isRecommended: true),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(cat),
              onSelected: (val) {
                setState(() => _selectedCategory = cat);
                _loadData();
              },
              selectedColor: const Color(0xFF6200EE).withOpacity(0.1),
              checkmarkColor: const Color(0xFF6200EE),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF6200EE) : Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _ideaCard(ProjectIdea idea, {bool isRecommended = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      borderOnForeground: true,
      side: BorderSide(color: Colors.grey.shade100),
      child: InkWell(
        onTap: () => context.push('/innovation/details/${idea.id}'),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6200EE).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      idea.category ?? 'General',
                      style: const TextStyle(color: Color(0xFF6200EE), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isRecommended)
                    const Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
                ],
              ),
              const SizedBox(height: 12),
              Text(idea.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                idea.description ?? 'No description provided.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.groups_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('${idea.collaborators.length} collaborators', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const Spacer(),
                  const Icon(Icons.bolt, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text('${(idea.innovationScore ?? 0).toStringAsFixed(1)} Innovation', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: idea.requiredSkills.take(3).map((s) => _skillTag(s)).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skillTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
    );
  }

  void _showCreateIdeaSheet() {
    // Navigate to Create Idea / AI Validation Screen
    context.push('/innovation/create');
  }
}
