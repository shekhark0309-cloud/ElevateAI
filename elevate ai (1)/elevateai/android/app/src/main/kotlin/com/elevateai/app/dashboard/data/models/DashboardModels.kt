package com.elevateai.app.dashboard.data.models

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonArray

@Serializable
data class OSDashboardData(
    val summary: DashboardSummary,
    val top_action: TopAction?,
    val opportunity_hub: JsonObject?,
    val career_center: JsonObject?,
    val network_hub: JsonObject?,
    val focus_center: JsonObject?,
    val scam_center: JsonObject?,
    val scholarship_hub: JsonObject?,
    val campus_hub: JsonObject?,
    val cafeteria_hub: JsonObject?,
    val portfolio_center: JsonObject?,
    val nudges: JsonArray,
    val archetype: String?,
    val academic_snapshot: AcademicSnapshot?
)

@Serializable
data class AcademicSnapshot(
    val synced: Boolean,
    val attendance: Double,
    val cgpa: Double,
    val progress: Double,
    val credits: Int,
    val backlogs: Int,
    val reliability: Double,
    val consistency: Double,
    val last_sync: String?
)

@Serializable
data class DashboardSummary(
    val trust_score: Double,
    val career_readiness: Double,
    val focus_score: Double,
    val productivity_score: Double,
    val streak: Int,
    val trend: String,
    val scholarship_readiness: Double? = 0.0,
    val team_readiness: Double? = 0.0
)

@Serializable
data class TopAction(
    val label: String,
    val action: String,
    val priority: String,
    val reason: String? = null
)
