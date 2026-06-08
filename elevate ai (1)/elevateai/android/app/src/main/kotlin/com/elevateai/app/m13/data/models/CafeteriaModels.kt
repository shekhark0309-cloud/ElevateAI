package com.elevateai.app.m13.data.models

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject

@Serializable
data class MealPreferences(
    val student_id: String,
    val opt_in_breakfast: Boolean,
    val opt_in_lunch: Boolean,
    val opt_in_dinner: Boolean,
    val opt_out_dates: List<String> = emptyList()
)

@Serializable
data class SustainabilityImpact(
    val personal_impact: PersonalImpact,
    val campus_impact: CampusImpact,
    val weekly_trends: List<JsonObject> = emptyList()
)

@Serializable
data class PersonalImpact(
    val meals_saved: Int,
    val food_saved_kg: Double,
    val co2_saved_kg: Double,
    val contribution_score: Double
)

@Serializable
data class CampusImpact(
    val total_food_saved_kg: Double,
    val participation_rate: Double,
    val active_students: Int
)

@Serializable
data class DailyMenu(
    val day: String,
    val breakfast: String,
    val lunch: String,
    val dinner: String
)
