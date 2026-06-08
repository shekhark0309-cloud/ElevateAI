package com.elevateai.app.dashboard.data.repository

import com.elevateai.app.dashboard.data.models.OSDashboardData
import io.github.jan_tennert.supabase.SupabaseClient
import io.github.jan_tennert.supabase.postgrest.postgrest
import io.github.jan_tennert.supabase.realtime.realtime
import io.github.jan_tennert.supabase.realtime.PostgresAction
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.merge
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
        val notifications = supabase.realtime.from("notifications")
            .postgresChangeFlow(schema = "public") { eq("student_id", studentId) }
            
        val trustScores = supabase.realtime.from("trust_scores")
            .postgresChangeFlow(schema = "public") { eq("student_id", studentId) }
            
        val applications = supabase.realtime.from("opportunity_applications")
            .postgresChangeFlow(schema = "public") { eq("student_id", studentId) }
            
        return merge(notifications, trustScores, applications)
    }

    fun observeDnaChanges(studentId: String): Flow<PostgresAction> {
        return supabase.realtime.from("student_dna")
            .postgresChangeFlow(schema = "public") {
                eq("student_id", studentId)
            }
    }
}
