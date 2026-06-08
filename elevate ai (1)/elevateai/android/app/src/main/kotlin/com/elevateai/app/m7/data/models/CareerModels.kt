package com.elevateai.app.m7.data.models

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject

@Serializable
data class CareerIntelligence(
    val score: Double,
    val risk_level: String,
    val gaps: List<String>,
    val next_actions: List<ActionItem>,
    val forecast: CareerForecast
)

@Serializable
data class ActionItem(
    val priority: String,
    val label: String,
    val action: String,
    val impact: String
)

@Serializable
data class CareerForecast(
    val current: Double,
    val d30: Double,
    val d90: Double
)
