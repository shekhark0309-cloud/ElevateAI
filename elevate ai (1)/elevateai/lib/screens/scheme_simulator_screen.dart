import 'package:flutter/material.dart';
import '../flutter_integration.dart';

class SchemeSimulatorScreen extends StatefulWidget {
  const SchemeSimulatorScreen({super.key});

  @override
  State<SchemeSimulatorScreen> createState() => _SchemeSimulatorScreenState();
}

class _SchemeSimulatorScreenState extends State<SchemeSimulatorScreen> {
  final _oppService = OpportunityService();
  final _buddyService = SchemeBuddyService();

  String _selectedState = 'Maharashtra';
  String _selectedCategory = 'General';
  double _income = 500000;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _schemes = [];
  final _buddyMsgCtrl = TextEditingController();

  final List<String> _indianStates = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
    'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram',
    'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu',
    'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
    'Andaman & Nicobar Islands', 'Chandigarh', 'Dadra & Nagar Haveli',
    'Daman & Diu', 'Delhi', 'Jammu & Kashmir', 'Ladakh', 'Lakshadweep', 'Puducherry'
  ];

  @override
  void dispose() {
    _buddyService.clearHistory();
    _buddyMsgCtrl.dispose();
    super.dispose();
  }

  void _findSchemes() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        // Update profile with form data first for better matching
        await supabase.from('student_profiles').update({
          'state': _selectedState,
          'category': _selectedCategory.toLowerCase(),
          'family_income': _income,
        }).eq('id', user.id);

        final res = await _oppService.getRankedOpportunities(
          studentId: user.id,
          typeFilter: ['scholarship'],
        );
        if (mounted) {
          setState(() {
            _schemes = List<Map<String, dynamic>>.from(res['opportunities'] ?? []);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _simulatePath(Map<String, dynamic> scheme) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await supabase.rpc('get_scheme_path', params: {
        'p_student_id': supabase.auth.currentUser!.id,
        'p_opportunity_id': scheme['id'],
      });

      if (mounted) Navigator.pop(context); // Close loading

      if (mounted) {
        _showPathResult(scheme['title'], result);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _showPathResult(String title, Map<String, dynamic> result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scheme Path: $title', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Success Probability', style: TextStyle(color: Colors.grey)),
                Text('${result['success_probability']}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo)),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: (result['success_probability'] as num).toDouble() / 100, minHeight: 8, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 24),
            const Text('REASONING:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Text(result['reason'] ?? 'Matches your profile archetype and income criteria.'),
            const SizedBox(height: 24),
            if (result['document_checklist'] != null) ...[
              const Text('DOCUMENT CHECKLIST:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 12),
              ...(result['document_checklist'] as List).map((doc) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(children: [const Icon(Icons.check_circle_outline, size: 16, color: Colors.green), const SizedBox(width: 8), Expanded(child: Text(doc))]),
              )),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ),
          ],
        ),
      ),
    );
  }

  void _askBuddy(String schemeName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _buildBuddySheet(schemeName),
    );
  }

  Widget _buildBuddySheet(String schemeName) {
    final messages = <Map<String, dynamic>>[
      {'role': 'assistant', 'content': 'नमस्ते! I am your Scheme Buddy. How can I help you with $schemeName?'}
    ];

    return StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Scheme Buddy Chat: $schemeName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final m = messages[index];
                  final isUser = m['role'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.indigo : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(m['content'], style: TextStyle(color: isUser ? Colors.white : Colors.black)),
                    ),
                  );
                },
              ),
            ),
            Row(
              children: [
                Expanded(child: TextField(controller: _buddyMsgCtrl, decoration: const InputDecoration(hintText: 'Type in Hindi or English...'))),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    final text = _buddyMsgCtrl.text;
                    if (text.isEmpty) return;
                    setSheetState(() => messages.add({'role': 'user', 'content': text}));
                    _buddyMsgCtrl.clear();

                    final user = supabase.auth.currentUser!;
                    final reply = await _buddyService.chat(studentId: user.id, message: text, language: 'hindi');
                    setSheetState(() => messages.add({'role': 'assistant', 'content': reply}));
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scheme Path Simulator')),
      body: _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildForm(),
                    const SizedBox(height: 32),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_schemes.isNotEmpty)
                      _buildResults()
                    else
                      _buildEmptyState(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildForm() {
    return Card(
      elevation: 0,
      color: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedState,
              decoration: const InputDecoration(labelText: 'Home State'),
              items: _indianStates.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _selectedState = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Category'),
              items: ['General', 'OBC', 'SC', 'ST'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _selectedCategory = v!),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Family Income', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('₹${(_income / 100000).toStringAsFixed(1)}L', style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: _income,
              min: 0,
              max: 2000000,
              divisions: 20,
              onChanged: (v) => setState(() => _income = v),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _findSchemes,
                style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
                child: const Text('Find Eligible Schemes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FOUND ${_schemes.length} ELIGIBLE SCHEMES', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 16),
        ..._schemes.map((s) => _schemeCard(s)).toList(),
      ],
    );
  }

  Widget _schemeCard(Map<String, dynamic> scheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(scheme['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Success Prob: ${scheme['match_score']}%'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => _simulatePath(scheme),
              child: const Text('SIMULATE'),
            ),
            TextButton(
              onPressed: () => _askBuddy(scheme['title']),
              child: const Text('ASK BUDDY'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        children: [
          Icon(Icons.account_balance, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Enter your profile details to see eligible schemes.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
