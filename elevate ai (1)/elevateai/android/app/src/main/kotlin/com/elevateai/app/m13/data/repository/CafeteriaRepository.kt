package com.elevateai.app.m13.data.repository

import com.elevateai.app.m13.data.models.*
import io.github.jan_tennert.supabase.SupabaseClient
import io.github.jan_tennert.supabase.postgrest.postgrest
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

class CafeteriaRepository(private val supabase: SupabaseClient) {

    suspend fun getMealPreferences(studentId: String): MealPreferences? {
        return supabase.postgrest.from("meal_preferences")
            .select()
            .eq("student_id", studentId)
            .maybeSingle()
            ?.decodeAs<MealPreferences>()
    }

    suspend fun updateMealPreferences(studentId: String, prefs: MealPreferences) {
        supabase.postgrest.from("meal_preferences")
            .upsert(prefs)
            .eq("student_id", studentId)
    }

    suspend fun getSustainabilityImpact(studentId: String): SustainabilityImpact {
        return supabase.postgrest.rpc(
            "get_student_sustainability_impact",
            buildJsonObject { put("p_student_id", studentId) }
        ).decodeAs<SustainabilityImpact>()
    }
    
    // Static menu for now as it usually follows a weekly cycle in colleges
    fun getWeeklyMenu(): List<DailyMenu> {
        return listOf(
            DailyMenu("Monday", "Poha & Tea", "Dal Tadka, Rice, Roti, Aloo Jeera", "Mix Veg, Roti, Rice"),
            DailyMenu("Tuesday", "Aloo Paratha", "Rajma Chawal, Roti, Salad", "Paneer Butter Masala, Naan"),
            DailyMenu("Wednesday", "Idli Sambhar", "Veg Pulao, Raita, Papad", "Bhindi Fry, Roti, Rice"),
            DailyMenu("Thursday", "Upma", "Kadhi Pakora, Rice, Roti", "Matar Paneer, Roti, Rice"),
            DailyMenu("Friday", "Bread Jam/Toast", "Chole Bhature, Lassi", "Dal Fry, Rice, Roti"),
            DailyMenu("Saturday", "Puri Bhaji", "Masala Khichdi, Kadhi", "Veg Manchurian, Fried Rice"),
            DailyMenu("Sunday", "Chole Kulche", "Special Thali", "Kheer & Puri")
        )
    }
}
