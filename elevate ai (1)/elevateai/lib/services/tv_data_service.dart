import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tv_models.dart';

class TVDataService {
  final _supabase = Supabase.instance.client;

  Future<StreamUrl> getLiveStream() async {
    // In a real app, this might fetch from a live streaming provider API (e.g. Mux, Agora)
    // For now, we return a configured placeholder or a specific live row from DB
    return StreamUrl(
      url: 'https://stream.elevateai.app/live/campus_tv.m3u8',
      format: 'hls',
    );
  }

  Future<List<BroadcastSchedule>> getSchedule() async {
    final response = await _supabase
        .from('broadcast_schedule')
        .select()
        .order('start_time', ascending: true);

    return (response as List).map((json) => BroadcastSchedule.fromJson(json)).toList();
  }

  Future<List<Recording>> getRecordings() async {
    final response = await _supabase
        .from('recordings')
        .select()
        .order('created_at', ascending: false);

    return (response as List).map((json) => Recording.fromJson(json)).toList();
  }
}
