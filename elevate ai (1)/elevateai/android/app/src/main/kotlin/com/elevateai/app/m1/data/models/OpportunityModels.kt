package com.elevateai.app.m1.data.models

import kotlinx.serialization.Serializable

@Serializable
data class RankedOpportunity(
    val id: String,
    val title: String,
    val type: String,
    val organizer_name: String,
    val prize_amount: Double? = null,
    val stipend_amount: Double? = null,
    val apply_deadline: String,
    val required_skills: List<String> = emptyList(),
    val banner_url: String? = null,
    val match_score: Int,
    val ai_reason: String,
    val ai_tip: String,
    val is_featured: Boolean = false,
    val is_verified: Boolean = false,
    val is_stretch_opportunity: Boolean = false
)

@Serializable
data class OpportunitySection(
    val title: String,
    val opportunities: List<RankedOpportunity>
)
