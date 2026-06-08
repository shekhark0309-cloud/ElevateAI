import 'package:flutter/material.dart';
import '../flutter_integration.dart';
import '../widgets/opportunity_card.dart';

class OpportunityFeedScreen extends StatefulWidget {
  const OpportunityFeedScreen({super.key});

  @override
  State<OpportunityFeedScreen> createState() => _OpportunityFeedScreenState();
}

class _OpportunityFeedScreenState extends State<OpportunityFeedScreen> {
  final _oppService = OpportunityService();
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _opportunities = [];

  @override
  void initState() {
    super.initState();
    _loadOpps();
  }

  Future<void> _loadOpps() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final res = await _oppService.getRankedOpportunities(studentId: user.id);
        if (mounted) {
          setState(() {
            _opportunities = List<Map<String, dynamic>>.from(res['opportunities'] ?? []);
            _isLoading = false;
          });
        }
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

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter Opportunities', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Category'),
              items: ['Hackathon', 'Scholarship', 'Internship', 'Job'].map((c) => DropdownMenuItem(value: c.toLowerCase(), child: Text(c))).toList(),
              onChanged: (v) {},
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Remote Only'),
              value: false,
              onChanged: (v) {},
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Apply Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Opportunities'),
        actions: [
          IconButton(
            onPressed: _showFilters,
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadOpps,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _opportunities.isEmpty
                ? const Center(child: Text('No matching opportunities found.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _opportunities.length,
                    itemBuilder: (context, index) => OpportunityCard(
                      opportunity: _opportunities[index],
                    ),
                  ),
      ),
    );
  }
}
