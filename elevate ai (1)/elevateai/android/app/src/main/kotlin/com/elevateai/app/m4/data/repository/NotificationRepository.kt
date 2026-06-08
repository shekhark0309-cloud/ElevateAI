package com.elevateai.app.m4.data.repository

import com.elevateai.app.m4.data.models.*
import io.github.jan_tennert.supabase.SupabaseClient
import io.github.jan_tennert.supabase.postgrest.postgrest
import io.github.jan_tennert.supabase.realtime.realtime
import io.github.jan_tennert.supabase.realtime.PostgresAction
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

class NotificationRepository(private val supabase: SupabaseClient) {

    suspend fun getNotifications(
        studentId: String,
        priority: String? = null,
        unreadOnly: Boolean = false
    ): List<Notification> {
        var query = supabase.postgrest.from("notifications")
            .select()
            .eq("student_id", studentId)

        if (priority != null) {
            query = query.eq("priority", priority)
        }
        if (unreadOnly) {
            query = query.eq("is_read", false)
        }

        return query.order("urgency", ascending = false)
            .order("created_at", ascending = false)
            .decodeList()
    }

    suspend fun getAIPriorities(studentId: String): List<PriorityAlert> {
        return supabase.postgrest.rpc(
            "get_focus_ai_priorities",
            buildJsonObject { put("p_student_id", studentId) }
        ).decodeList()
    }

    suspend fun markAsRead(notificationId: String) {
        supabase.postgrest.from("notifications")
            .update(buildJsonObject { put("is_read", true) })
            .eq("id", notificationId)
    }

    fun observeNotifications(studentId: String): Flow<PostgresAction> {
        return supabase.realtime.from("notifications")
            .postgresChangeFlow(schema = "public") {
                eq("student_id", studentId)
            }
    }
}
