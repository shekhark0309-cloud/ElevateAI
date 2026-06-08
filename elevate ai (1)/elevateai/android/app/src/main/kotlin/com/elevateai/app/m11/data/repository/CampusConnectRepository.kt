package com.elevateai.app.m11.data.repository

import com.elevateai.app.m11.data.models.*
import io.github.jan_tennert.supabase.SupabaseClient
import io.github.jan_tennert.supabase.postgrest.postgrest
import io.github.jan_tennert.supabase.realtime.realtime
import io.github.jan_tennert.supabase.realtime.PostgresAction
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

class CampusConnectRepository(private val supabase: SupabaseClient) {

    suspend fun getDiscoveryFeed(
        studentId: String,
        filterType: String = "all",
        limit: Int = 20
    ): List<DiscoveryStudent> {
        return supabase.postgrest.rpc(
            "get_student_discovery_feed",
            buildJsonObject {
                put("p_student_id", studentId)
                put("p_filter_type", filterType)
                put("p_limit", limit)
            }
        ).decodeList()
    }

    suspend fun manageConnection(
        targetId: String,
        action: String,
        type: String = "study_buddy",
        subject: String? = null
    ) {
        supabase.postgrest.rpc(
            "manage_campus_connection",
            buildJsonObject {
                put("p_target_student_id", targetId)
                put("p_action", action)
                put("p_connection_type", type)
                put("p_subject", subject)
            }
        )
    }

    suspend fun getStudyGroups(studentId: String): List<StudyGroup> {
        return supabase.postgrest.from("teams")
            .select()
            .eq("category", "study_group")
            .decodeList()
    }

    suspend fun createStudyGroup(group: StudyGroup): StudyGroup {
        return supabase.postgrest.from("teams")
            .insert(group)
            .select()
            .single()
            .decodeAs()
    }

    fun observeConnectionRequests(studentId: String): Flow<PostgresAction> {
        return supabase.realtime.from("campus_connections")
            .postgresChangeFlow(schema = "public") {
                eq("student_b_id", studentId)
            }
    }
}
