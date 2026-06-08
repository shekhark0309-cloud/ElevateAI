package com.elevateai.app.m11.data.models

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject

@Serializable
data class DiscoveryStudent(
    val student_id: String,
    val full_name: String,
    val avatar_url: String?,
    val course: String?,
    val year_of_study: Int,
    val archetype: String?,
    val trust_score: Double,
    val top_skills: List<String>,
    val shared_skills: List<String>,
    val shared_interests: List<String>,
    val match_score: Int,
    val compatibility: JsonObject
)

@Serializable
data class ConnectionRequest(
    val id: String,
    val sender_id: String,
    val receiver_id: String,
    val connection_type: String,
    val status: String,
    val created_at: String
)

@Serializable
data class StudyGroup(
    val id: String,
    val name: String,
    val tagline: String?,
    val leader_id: String,
    val category: String = "study_group",
    val required_skills: List<String> = emptyList(),
    val max_members: Int = 5,
    val status: String = "forming"
)
