package com.elevateai.app.m5.data.repository

import com.elevateai.app.m5.data.models.*
import io.github.jan_tennert.supabase.SupabaseClient
import io.github.jan_tennert.supabase.postgrest.postgrest
import io.github.jan_tennert.supabase.realtime.realtime
import io.github.jan_tennert.supabase.realtime.PostgresAction
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

class FocusRepository(private val supabase: SupabaseClient) {

    suspend fun getIntelligence(studentId: String): FocusIntelligence {
        return supabase.postgrest.rpc(
            "get_focus_intelligence",
            buildJsonObject { put("p_student_id", studentId) }
        ).decodeAs()
    }

    suspend fun manageSession(action: String, mode: String = "deep_work", duration: Int = 0) {
        supabase.postgrest.rpc(
            "manage_focus_session",
            buildJsonObject {
                put("p_action", action)
                put("p_mode", mode)
                put("p_duration", duration)
            }
        )
    }

    suspend fun getRecentSessions(studentId: String): List<FocusSession> {
        return supabase.postgrest.from("focus_sessions")
            .select()
            .eq("student_id", studentId)
            .order("created_at", ascending = false)
            .limit(10)
            .decodeList()
    }

    fun observeSessions(studentId: String): Flow<PostgresAction> {
        return supabase.realtime.from("focus_sessions")
            .postgresChangeFlow(schema = "public") {
                eq("student_id", studentId)
            }
    }
}
