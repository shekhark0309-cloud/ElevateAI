package com.elevateai.app.dashboard.data.repository

import com.elevateai.app.dashboard.data.models.OSDashboardData
import io.github.jan_tennert.supabase.SupabaseClient
import io.github.jan_tennert.supabase.postgrest.postgrest
import io.github.jan_tennert.supabase.realtime.realtime
import io.github.jan_tennert.supabase.realtime.PostgresAction
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

class DashboardRepository(private val supabase: SupabaseClient) {

    suspend fun getOSDashboard(studentId: String): OSDashboardData {
        return supabase.postgrest.rpc(
            "get_student_os_dashboard",
            buildJsonObject { put("p_student_id", studentId) }
        ).decodeAs()
    }

    fun observeDashboardSignals(studentId: String): Flow<PostgresAction> {
        // Monitor notifications and trust scores for realtime dashboard updates
        return supabase.realtime.from("notifications")
            .postgresChangeFlow(schema = "public") {
                eq("student_id", studentId)
            }
    }
}
