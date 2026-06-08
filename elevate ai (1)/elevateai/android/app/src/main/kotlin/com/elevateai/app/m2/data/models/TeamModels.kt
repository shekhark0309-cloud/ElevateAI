package com.elevateai.app.m2.data.models

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject

@Serializable
data class TeamMatch(
    val id: String,
    val name: String,
    val tagline: String?,
    val leader_name: String,
    val leader_trust_score: Double,
    val composite_score: Double,
    val required_skills: List<String>,
    val current_member_count: Int,
    val max_members: Int,
    val match_explanation: String?,
    val leader_availability: String?,
    val leader_location: String?
)

@Serializable
data class NearbyTeammate(
    val student_id: String,
    val full_name: String,
    val avatar_url: String?,
    val archetype: String?,
    val top_skills: List<String>,
    val trust_score: Double,
    val availability: String,
    val distance_meters: Int,
    val match_score: Int
)

@Serializable
data class TeamAnalysis(
    val health_score: Int,
    val missing_roles: List<String>,
    val team_strength_summary: String,
    val strengths: JsonObject,
    val compatibility_score: Int
)
