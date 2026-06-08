package com.elevateai.app.m19.data.repository

import com.elevateai.app.m19.data.models.*
import io.github.jan_tennert.supabase.SupabaseClient
import io.github.jan_tennert.supabase.postgrest.postgrest
import io.github.jan_tennert.supabase.realtime.realtime
import io.github.jan_tennert.supabase.realtime.PostgresAction
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

class PeerNetworkRepository(private val supabase: SupabaseClient) {

    suspend fun getSuccessStoryFeed(studentId: String, limit: Int = 20): List<SuccessStoryFeedItem> {
        return supabase.postgrest.rpc(
            "get_success_story_feed",
            buildJsonObject {
                put("p_student_id", studentId)
                put("p_limit", limit)
            }
        ).decodeList()
    }

    suspend fun getStoryDetails(storyId: String): SuccessStory {
        return supabase.postgrest.from("success_stories")
            .select()
            .eq("id", storyId)
            .single()
            .decodeAs()
    }

    suspend fun requestGuidance(
        mentorId: String,
        opportunityId: String,
        subject: String,
        message: String
    ) {
        supabase.postgrest.rpc(
            "manage_guidance_request",
            buildJsonObject {
                put("p_mentor_id", mentorId)
                put("p_opportunity_id", opportunityId)
                put("p_subject", subject)
                put("p_message", message)
            }
        )
    }

    fun observeGuidanceRequests(userId: String): Flow<PostgresAction> {
        return supabase.realtime.from("guidance_requests")
            .postgresChangeFlow(schema = "public") {
                // Monitor where I am either requester or mentor
                // Complex filter might need multiple subscriptions or a more general one
            }
    }
}
