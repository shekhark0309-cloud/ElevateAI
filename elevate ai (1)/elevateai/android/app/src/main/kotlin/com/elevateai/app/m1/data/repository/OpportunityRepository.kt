package com.elevateai.app.m1.data.repository

import com.elevateai.app.m1.data.models.RankedOpportunity
import io.github.jan_tennert.supabase.SupabaseClient
import io.github.jan_tennert.supabase.functions.functions
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
        val data = response.decodeAs<JsonObject>()
        val list = data["opportunities"]?.jsonArray ?: return emptyList()
        
        return list.map { Json.decodeFromJsonElement<RankedOpportunity>(it) }
    }
}
