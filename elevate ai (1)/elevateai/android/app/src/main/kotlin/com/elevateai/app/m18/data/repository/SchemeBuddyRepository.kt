package com.elevateai.app.m18.data.repository

import io.github.jan_tennert.supabase.SupabaseClient
import io.github.jan_tennert.supabase.functions.functions
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.add
import kotlinx.serialization.json.buildJsonArray

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
}
