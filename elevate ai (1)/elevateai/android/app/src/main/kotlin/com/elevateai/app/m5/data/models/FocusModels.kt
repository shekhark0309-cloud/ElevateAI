package com.elevateai.app.m5.data.models

import kotlinx.serialization.Serializable

@Serializable
data class FocusIntelligence(
    val risk_level: String,
    val productivity_score: Double,
    val days_inactive: Int,
    val intervention: String,
    val today_minutes: Int,
    val current_streak: Int
)

@Serializable
data class FocusSession(
    val id: String? = null,
    val student_id: String,
    val start_at: String? = null,
    val end_at: String? = null,
    val duration_seconds: Int = 0,
    val status: String = "active",
    val focus_mode: String = "deep_work"
)
