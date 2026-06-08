package com.elevateai.app.m1.data.repository

import com.elevateai.app.m1.data.models.RankedOpportunity
import io.github.jan_tennert.supabase.SupabaseClient
import io.github.jan_tennert.supabase.functions.functions
import io.github.jan_tennert.supabase.realtime.realtime
import io.github.jan_tennert.supabase.realtime.PostgresAction
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.json.*

class OpportunityRepository(private val supabase: SupabaseClient) {

    suspend fun getRankedOpportunities(studentId: String): List<RankedOpportunity> {
        val response = supabase.functions.invoke(
            "rank-opportunities",
            buildJsonObject {
                put("student_id", studentId)
                put("limit", 40)
            }
        )
        val body = response.decodeAs<JsonObject>()
        val data = body["data"]?.jsonObject ?: return emptyList()
        val list = data["opportunities"]?.jsonArray ?: return emptyList()
        
        return list.map { Json.decodeFromJsonElement<RankedOpportunity>(it) }
    }

    fun observeApplications(studentId: String): Flow<PostgresAction> {
        return supabase.realtime.from("opportunity_applications")
            .postgresChangeFlow(schema = "public") {
                eq("student_id", studentId)
            }
    }
}
