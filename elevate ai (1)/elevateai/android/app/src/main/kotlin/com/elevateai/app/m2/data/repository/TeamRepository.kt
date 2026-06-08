package com.elevateai.app.m2.data.repository

import com.elevateai.app.m2.data.models.*
import io.github.jan_tennert.supabase.SupabaseClient
import io.github.jan_tennert.supabase.functions.functions
import io.github.jan_tennert.supabase.postgrest.postgrest
import io.github.jan_tennert.supabase.realtime.realtime
import io.github.jan_tennert.supabase.realtime.PostgresAction
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.decodeFromJsonElement

class TeamRepository(private val supabase: SupabaseClient) {

    suspend fun getTeamMatches(studentId: String): List<TeamMatch> {
        val response = supabase.functions.invoke(
            "match-teams",
            buildJsonObject { put("student_id", studentId) }
        )
        // match-teams returns { matches: [...] }
        val matchesJson = response.decodeAs<JsonObject>()["matches"]?.jsonArray ?: return emptyList()
        return matchesJson.map { Json.decodeFromJsonElement<TeamMatch>(it) }
    }

    suspend fun getNearbyTeammates(studentId: String, radiusKm: Double = 2.0): List<NearbyTeammate> {
        return supabase.postgrest.rpc(
            "get_nearby_teammates",
            buildJsonObject {
                put("p_student_id", studentId)
                put("p_radius_km", radiusKm)
            }
        ).decodeList()
    }

    suspend fun updateAvailability(studentId: String, status: String) {
        supabase.postgrest.from("student_profiles")
            .update(buildJsonObject { put("availability_status", status) })
            .eq("id", studentId)
    }

    fun observeAvailability(collegeId: String): Flow<PostgresAction> {
        return supabase.realtime.from("student_profiles")
            .postgresChangeFlow(schema = "public") {
                eq("college_id", collegeId)
            }
    }

    fun observeTeamChanges(studentId: String): Flow<PostgresAction> {
        return supabase.realtime.from("team_members")
            .postgresChangeFlow(schema = "public") {
                eq("student_id", studentId)
            }
    }
}
