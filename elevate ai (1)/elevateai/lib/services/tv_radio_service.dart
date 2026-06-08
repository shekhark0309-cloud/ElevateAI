import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tv_models.dart';

class TVRadioService {
  final _supabase = Supabase.instance.client;

  Future<StreamUrl> getLiveAudio() async {
    return StreamUrl(
      url: 'https://radio.elevateai.app/live/campus_fm.mp3',
      format: 'mp3',
    );
  }

  Future<RadioShow?> getCurrentShow() async {
    final now = DateTime.now().toIso8601String();
    final response = await _supabase
        .from('radio_shows')
        .select()
        .lte('start_time', now)
        .gte('end_time', now)
        .maybeSingle();

    if (response == null) return null;
    return RadioShow.fromJson(response);
  }
}
