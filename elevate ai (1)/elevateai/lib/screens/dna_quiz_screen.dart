import 'package:flutter/material.dart';
import '../flutter_integration.dart';

class DNAQuizScreen extends StatefulWidget {
  const DNAQuizScreen({super.key});

  @override
  State<DNAQuizScreen> createState() => _DNAQuizScreenState();
}

class _DNAQuizScreenState extends State<DNAQuizScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  final List<Map<String, String>> _responses = [];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final res = await supabase.from('dna_quiz_questions').select().order('display_order');
      if (mounted) {
        if ((res as List).isEmpty) {
           setState(() {
            _errorMessage = "No questions available";
            _isLoading = false;
          });
          return;
        }
        setState(() {
          _questions = List<Map<String, dynamic>>.from(res);
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

  void _onSelect(String option) {
    _responses.add({
      'question_id': _questions[_currentIndex]['id'],
      'selected_option': option,
    });

    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      String archetype = '';

      if (user != null) {
        // Logged in user: Save to DB
        final result = await supabase.rpc('submit_dna_quiz', params: {
          'p_student_id': user.id,
          'p_responses': _responses,
        });
        archetype = result['archetype'] as String;
      } else {
        // New user (Onboarding/Test Mode): Calculate locally
        archetype = _calculateLocalArchetype();
        // Save locally for persistence in Test Mode
        await LocalDatabaseService().cacheData('cached_dna', 'guest_user', {'archetype': archetype});
      }

      if (mounted) {
        _showArchetypeReveal(archetype);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  String _calculateLocalArchetype() {
    Map<String, int> counts = {'Builder': 0, 'Strategist': 0, 'Creative': 0, 'Executor': 0};

    for (var resp in _responses) {
      final qId = resp['question_id'];
      final opt = resp['selected_option'];
      final q = _questions.firstWhere((element) => element['id'] == qId);

      String? arch;
      if (opt == 'a') arch = q['archetype_a'];
      else if (opt == 'b') arch = q['archetype_b'];
      else if (opt == 'c') arch = q['archetype_c'];
      else if (opt == 'd') arch = q['archetype_d'];

      if (arch != null && counts.containsKey(arch)) {
        counts[arch] = counts[arch]! + 1;
      }
    }

    var sortedKeys = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return sortedKeys.first;
  }

  void _showArchetypeReveal(String archetype) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧬 DNA UNLOCKED', style: TextStyle(letterSpacing: 2, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            const Icon(Icons.auto_awesome, size: 80, color: Colors.indigo),
            const SizedBox(height: 24),
            const Text('You are a', style: TextStyle(fontSize: 18)),
            Text(archetype, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 24),
            const Text(
              'Your Work Style DNA has been set. Team matches and opportunities will now be personalised.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context, archetype); // Return result
                },
                child: const Text('Start My Journey'),
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
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _buildQuizContent(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'No Questions Found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Please ensure you have added questions to the database.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizContent() {
    final q = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: progress, minHeight: 8, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 12),
            Text('Question ${_currentIndex + 1} of ${_questions.length}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 48),
            Text(q['question_text'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 48),
            Expanded(
              child: ListView(
                children: [
                  _optionCard('a', q['option_a']),
                  _optionCard('b', q['option_b']),
                  _optionCard('c', q['option_c']),
                  _optionCard('d', q['option_d']),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionCard(String key, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: OutlinedButton(
        onPressed: () => _onSelect(key),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text, style: const TextStyle(fontSize: 16, color: Colors.black)),
        ),
      ),
    );
  }
}
