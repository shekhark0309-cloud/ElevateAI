package com.elevateai.app.m4.data.models

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement

@Serializable
data class Notification(
    val id: String,
    val student_id: String,
    val type: String,
    val title: String,
    val body: String?,
    val data: JsonElement? = null,
    val priority: String = "medium",
    val urgency: Int = 5,
    val action_label: String? = null,
    val action_url: String? = null,
    val is_read: Boolean = false,
    val is_actioned: Boolean = false,
    val created_at: String
)

@Serializable
data class PriorityAlert(
    val type: String,
    val title: String,
    val priority: String,
    val action_label: String,
    val action_url: String
)
