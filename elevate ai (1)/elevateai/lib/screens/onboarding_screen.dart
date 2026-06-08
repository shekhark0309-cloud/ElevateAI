import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../flutter_integration.dart';
import '../config/notification_service.dart';
import 'dna_quiz_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  int _currentStep = 0;
  String _selectedArchetype = '';
  String _selectedCollegeId = '';
  List<Map<String, dynamic>> _colleges = [];
  bool _loadingColleges = false;
  bool _isSigningUp = false;
  String? _fetchError;

  @override
  void initState() {
    super.initState();
    _loadColleges();
    _checkGuestDNA();
  }

  Future<void> _checkGuestDNA() async {
    try {
      final db = LocalDatabaseService();
      final database = await db.database;
      final res = await database.query('cached_dna', where: 'student_id = ?', whereArgs: ['guest_user']);

      if (res.isNotEmpty && mounted) {
        final data = jsonDecode(res.first['data'] as String);
        setState(() {
          _selectedArchetype = data['archetype'];
          _currentStep = 1;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadColleges() async {
    if (!mounted) return;
    setState(() {
      _loadingColleges = true;
      _fetchError = null;
    });
    try {
      final data = await supabase
          .from('colleges')
          .select('id, name')
          .order('name');

      if (mounted) {
        setState(() {
          _colleges = List<Map<String, dynamic>>.from(data);
          _loadingColleges = false;
          if (_colleges.isEmpty) {
            _fetchError = "No colleges found in database.";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fetchError = "Database Error: ${e.toString()}";
          _loadingColleges = false;
        });
      }
    }
  }

  void _startQuiz() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DNAQuizScreen()),
    );
    if (result != null) {
      setState(() {
        _selectedArchetype = result;
        _currentStep = 1;
      });
    }
  }

  void _signUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_selectedCollegeId.isEmpty) {
      _showSnack('Please select your college');
      return;
    }
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnack('Please fill in all fields');
      return;
    }
    if (password.length < 6) {
      _showSnack('Password must be at least 6 characters');
      return;
    }

    setState(() => _isSigningUp = true);

    try {
      final res = await _authService.signUpStudent(
        email:     email,
        password:  password,
        fullName:  name,
        collegeId: _selectedCollegeId,
        archetype: _selectedArchetype.isNotEmpty ? _selectedArchetype : null,
      );

      if (mounted) {
        // Check if session was created (auto-login)
        if (res.session != null) {
          // Cleanup guest DNA
          final db = LocalDatabaseService();
          final database = await db.database;
          await database.delete('cached_dna', where: 'student_id = ?', whereArgs: ['guest_user']);

          await PushNotificationService.registerAfterLogin();
          context.go('/main');
        } else {
          // Session is null -> Email confirmation might be required
          _showEmailConfirmationDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSigningUp = false);
        _showSnack('Sign up failed: ${e.toString()}');
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showEmailConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Verify Your Email'),
        content: const Text('A confirmation link has been sent to your email. Please check your inbox and verify your account to continue.'),
        actions: [
          TextButton(
            onPressed: () => context.go('/welcome'),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _currentStep == 0 ? _buildQuiz() : _buildSignUp(),
        ),
      ),
    );
  }

  Widget _buildQuiz() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '🧬 Discover Your DNA',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Take our behavioral quiz to discover your professional archetype.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: FilledButton.icon(
            onPressed: _startQuiz,
            icon: const Icon(Icons.quiz_outlined),
            label: const Text('Start DNA Quiz', style: TextStyle(fontSize: 18)),
            style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _currentStep = 1),
          child: const Text('Skip for now'),
        ),
      ],
    );
  }

  Widget _buildSignUp() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => setState(() => _currentStep = 0),
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(height: 20),
          const Text('Create Your Account', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          if (_selectedArchetype.isNotEmpty)
             Padding(
               padding: const EdgeInsets.only(top: 8.0),
               child: Text('DNA Found: $_selectedArchetype', style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
             ),
          const Text('Join the ElevateAI Student Success OS', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),

          if (_fetchError != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  Text(_fetchError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  TextButton(onPressed: _loadColleges, child: const Text("Retry")),
                ],
              ),
            ),

          if (_loadingColleges)
            const LinearProgressIndicator()
          else
            DropdownButtonFormField<String>(
              value: _selectedCollegeId.isEmpty ? null : _selectedCollegeId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Select Your College *',
                border: OutlineInputBorder(),
              ),
              items: _colleges.map((c) => DropdownMenuItem<String>(
                value: c['id'] as String,
                child: Text(c['name'] as String, overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (v) => setState(() => _selectedCollegeId = v ?? ''),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'College Email', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password (min. 6 chars)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: _isSigningUp ? null : _signUp,
              style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
              child: _isSigningUp
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Start My Journey', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
