package com.elevateai.app.m19.data.models

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement

@Serializable
data class SuccessStory(
    val id: String? = null,
    val student_id: String,
    val opportunity_id: String,
    val approval_year: Int,
    val amount_received: Double,
    val journey_summary: String,
    val success_factors: List<String> = emptyList(),
    val challenges_faced: String? = null,
    val strategy: String? = null,
    val mistakes_avoided: String? = null,
    val document_tips: String? = null,
    val application_steps: JsonElement? = null,
    val is_verified: Boolean = false,
    val created_at: String? = null
)

@Serializable
data class SuccessStoryFeedItem(
    val story_id: String,
    val student_name: String,
    val avatar_url: String?,
    val opportunity_title: String,
    val approval_year: Int,
    val amount_received: Double,
    val journey_summary: String,
    val match_score: Int
)

@Serializable
data class GuidanceRequest(
    val id: String? = null,
    val requester_id: String,
    val mentor_id: String,
    val opportunity_id: String,
    val subject: String,
    val message: String,
    val status: String = "pending",
    val created_at: String? = null
)
