package com.elevateai.app.m3.data.models

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement

@Serializable
data class ProjectIdea(
    val id: String? = null,
    val creator_id: String,
    val title: String,
    val description: String? = null,
    val problem_statement: String? = null,
    val solution: String? = null,
    val target_users: String? = null,
    val required_skills: List<String> = emptyList(),
    val stage: String = "idea",
    val collaborators: List<String> = emptyList(),
    val innovation_score: Double? = null,
    val feasibility_score: Double? = null,
    val market_potential: String? = null,
    val technical_complexity: String? = null,
    val suggested_improvements: List<String> = emptyList(),
    val potential_risks: List<String> = emptyList(),
    val category: String? = null,
    val tags: List<String> = emptyList(),
    val created_at: String? = null
)

@Serializable
data class IdeaFeedItem(
    val idea_id: String,
    val creator_name: String,
    val title: String,
    val description: String?,
    val required_skills: List<String>,
    val innovation_score: Double?,
    val collaborator_count: Int,
    val match_score: Double,
    val created_at: String
)

@Serializable
data class IdeaValidation(
    val innovation_score: Int,
    val feasibility_score: Int,
    val market_potential: String,
    val technical_complexity: String,
    val implementation_difficulty: String,
    val suggested_improvements: List<String>,
    val potential_risks: List<String>,
    val suggested_team_roles: List<String>,
    val hackathon_suitability: String
)
