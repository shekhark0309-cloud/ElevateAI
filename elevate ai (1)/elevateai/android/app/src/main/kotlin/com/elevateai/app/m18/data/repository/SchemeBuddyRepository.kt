package com.elevateai.app.m18.data.repository

import io.github.jan_tennert.supabase.SupabaseClient
import io.github.jan_tennert.supabase.functions.functions
import io.github.jan_tennert.supabase.postgrest.postgrest
import kotlinx.serialization.json.*

class SchemeBuddyRepository(private val supabase: SupabaseClient) {

    suspend fun chat(
        studentId: String,
        message: String,
        language: String = "auto",
        history: JsonArray = buildJsonArray {}
    ): JsonObject {
        val response = supabase.functions.invoke(
            "scheme-buddy-chat",
            buildJsonObject {
                put("student_id", studentId)
                put("message", message)
                put("language", language)
                put("conversation_history", history)
            }
        )
        return response.decodeAs<JsonObject>()
    }

    suspend fun getSchemePath(studentId: String, opportunityId: String): JsonObject {
        return supabase.postgrest.rpc(
            "get_scheme_path",
            buildJsonObject {
                put("p_student_id", studentId)
                put("p_opportunity_id", opportunityId)
            }
        ).decodeAs()
    }

    suspend fun getPeerSuccessStories(studentId: String, opportunityId: String): JsonArray {
        return supabase.postgrest.rpc(
            "get_peer_success_stories",
            buildJsonObject {
                put("p_student_id", studentId)
                put("p_opportunity_id", opportunityId)
            }
        ).decodeAs()
    }
}
