package com.elevateai.app.m3.data.repository

import com.elevateai.app.m3.data.models.*
import io.github.jan_tennert.supabase.SupabaseClient
import io.github.jan_tennert.supabase.postgrest.postgrest
import io.github.jan_tennert.supabase.functions.functions
import io.github.jan_tennert.supabase.realtime.realtime
import io.github.jan_tennert.supabase.realtime.PostgresAction
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

class InnovationRepository(private val supabase: SupabaseClient) {

    suspend fun getDiscoveryFeed(
        studentId: String,
        sortBy: String = "trending",
        category: String = "All"
    ): List<IdeaFeedItem> {
        return supabase.postgrest.rpc(
            "get_innovation_hub_feed",
            buildJsonObject {
                put("p_student_id", studentId)
                put("p_sort_by", sortBy)
                put("p_category", category)
            }
        ).decodeList()
    }

    suspend fun getIdeaDetails(ideaId: String): ProjectIdea {
        return supabase.postgrest.from("project_ideas")
            .select()
            .eq("id", ideaId)
            .single()
            .decodeAs()
    }

    suspend fun validateIdea(
        title: String,
        description: String,
        problem: String?,
        solution: String?
    ): IdeaValidation {
        val response = supabase.functions.invoke(
            "analyze-idea",
            buildJsonObject {
                put("title", title)
                put("description", description)
                put("problem_statement", problem)
                put("solution", solution)
            }
        )
        val body = response.decodeAs<JsonObject>()
        return Json.decodeFromJsonElement(body["data"]!!)
    }

    suspend fun joinIdea(ideaId: String, studentId: String) {
        supabase.postgrest.rpc(
            "join_project_idea",
            buildJsonObject {
                put("p_idea_id", ideaId)
                put("p_student_id", studentId)
            }
        )
    }

    suspend fun createIdea(idea: ProjectIdea): ProjectIdea {
        return supabase.postgrest.from("project_ideas")
            .insert(idea)
            .select()
            .single()
            .decodeAs()
    }

    fun subscribeToIdeaUpdates(ideaId: String): Flow<PostgresAction> {
        return supabase.realtime.from("project_ideas")
            .postgresChangeFlow(schema = "public") {
                eq("id", ideaId)
            }
    }
}
