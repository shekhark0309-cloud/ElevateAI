import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  Future<AuthResponse> signUpStudent({
    required String email,
    required String password,
    required String fullName,
    required String collegeId,
    String? archetype,
    String? rollNumber,
    String? course,
    String? branch,
    int? yearOfStudy,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'college_id': collegeId,
        if (archetype != null) 'archetype': archetype,
        if (rollNumber != null) 'roll_number': rollNumber,
        if (course != null) 'course': course,
        if (branch != null) 'branch': branch,
        if (yearOfStudy != null) 'year_of_study': yearOfStudy,
      },
      emailRedirectTo: 'io.supabase.elevateai://login-callback',
    );
  }

  Future<void> sendMagicLink(String email) async {
    await _supabase.auth.signInWithOtp(
      email: email,
      emailRedirectTo: 'io.supabase.elevateai://login-callback',
      shouldCreateUser: false,
    );
  }

  Future<void> sendPhoneOTP(String phone) async {
    await _supabase.auth.signInWithOtp(
      phone: phone,
    );
  }

  Future<AuthResponse> verifyPhoneOTP({
    required String phone,
    required String otp,
  }) async {
    return await _supabase.auth.verifyOTP(
      phone: phone,
      token: otp,
      type: OtpType.sms,
    );
  }

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
