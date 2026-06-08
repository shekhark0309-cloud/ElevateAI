package com.elevateai.app.m7.data.repository

import com.elevateai.app.m7.data.models.CareerIntelligence
import io.github.jan_tennert.supabase.SupabaseClient
import io.github.jan_tennert.supabase.postgrest.postgrest
import io.github.jan_tennert.supabase.realtime.realtime
import io.github.jan_tennert.supabase.realtime.PostgresAction
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

class CareerRepository(private val supabase: SupabaseClient) {

    suspend fun getCareerIntelligence(studentId: String): CareerIntelligence {
        return supabase.postgrest.rpc(
            "get_career_roadmap_intelligence",
            buildJsonObject { put("p_student_id", studentId) }
        ).decodeAs()
    }

    fun observeCareerUpdates(studentId: String): Flow<PostgresAction> {
        return supabase.realtime.from("student_dna")
            .postgresChangeFlow(schema = "public") {
                eq("student_id", studentId)
            }
    }
}
