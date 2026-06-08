package com.elevateai.app

import io.github.jan_tennert.supabase.SupabaseClient
import io.github.jan_tennert.supabase.createSupabaseClient
import io.github.jan_tennert.supabase.postgrest.Postgrest
import io.github.jan_tennert.supabase.gotrue.GoTrue
import io.github.jan_tennert.supabase.gotrue.gotrue
import io.github.jan_tennert.supabase.realtime.Realtime
import io.github.jan_tennert.supabase.functions.Functions
import kotlinx.serialization.json.Json

object SupabaseManager {
    private var client: SupabaseClient? = null

    // Hardcoded for bridge purposes, should match Flutter AppConfig
    private const val SUPABASE_URL = "https://buwiiyklldzfiryjqfyv.supabase.co"
    private const val SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ1d2lpeWtsbGR6ZmlyeWpxZnl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1ODkxOTYsImV4cCI6MjA5NjE2NTE5Nn0.dakH3RuXtJ-hz7e-XSfwBo6T2VfIguANML4zzuXajlw"

    fun getClient(): SupabaseClient {
        return client ?: synchronized(this) {
            val instance = createSupabaseClient(
                supabaseUrl = SUPABASE_URL,
                supabaseKey = SUPABASE_ANON_KEY
            ) {
                install(Postgrest)
                install(GoTrue)
                install(Realtime)
                install(Functions)
            }
            client = instance
            instance
        }
    }

    suspend fun syncSession(sessionJson: String?) {
        if (sessionJson == null) return
        try {
            getClient().gotrue.importSession(sessionJson)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
