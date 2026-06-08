import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import {
  createServiceClient,
  successResponse,
  errorResponse,
  optionsResponse,
} from "../_shared/utils.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") return optionsResponse();

  try {
    const { college_id, date: inputDate } = await req.json();

    if (!college_id) {
      return errorResponse("college_id is required", 400);
    }

    const date = inputDate || new Date(Date.now() + 86400000).toISOString().split('T')[0];
    const supabase = createServiceClient();

    // 1. Fetch total enrolled students
    const { count: totalEnrolled, error: countError } = await supabase
      .from("student_profiles")
      .select("*", { count: "exact", head: true })
      .eq("college_id", college_id)
      .eq("is_active", true);

    if (countError) throw countError;

    const mealTypes = ["breakfast", "lunch", "dinner"];
    const predictions: Record<string, any> = {};

    for (const mealType of mealTypes) {
      // 2. Count opted-out students
      const { count: optedOutCount, error: optOutError } = await supabase
        .from("meal_preferences")
        .select("*", { count: "exact", head: true })
        .filter("student_id", "in", `(SELECT id FROM student_profiles WHERE college_id = '${college_id}' AND is_active = true)`)
        .or(`opt_in_${mealType}.eq.false,opt_out_dates.cs.{"${date}"}`);

      if (optOutError) throw optOutError;

      const optedInCount = (totalEnrolled || 0) - (optedOutCount || 0);
      const predictedCount = Math.min(totalEnrolled || 0, Math.ceil(optedInCount * 1.10));
      const wasteKgSaved = (optedOutCount || 0) * 0.35;

      // 3. Upsert prediction
      await supabase.from("meal_predictions").upsert({
        college_id,
        meal_date: date,
        meal_type: mealType,
        predicted_count: predictedCount,
        waste_kg_saved: wasteKgSaved,
      }, { onConflict: "college_id,meal_date,meal_type" });

      predictions[mealType] = { predicted_count: predictedCount, waste_kg_saved: wasteKgSaved };
    }

    // 4. Compute weekly totals for notifications
    const { data: weeklyData, error: weeklyError } = await supabase
      .from("meal_predictions")
      .select("waste_kg_saved")
      .eq("college_id", college_id)
      .gte("meal_date", new Date(new Date(date).getTime() - 7 * 86400000).toISOString().split('T')[0])
      .lte("meal_date", date);

    if (weeklyError) throw weeklyError;

    const weeklyWasteSaved = weeklyData.reduce((sum, item) => sum + (item.waste_kg_saved || 0), 0);

    if (weeklyWasteSaved > 50) {
      const { data: students } = await supabase
        .from("student_profiles")
        .select("id")
        .eq("college_id", college_id)
        .eq("is_active", true);

      if (students) {
        const notifications = students.map(s => ({
          student_id: s.id,
          type: "sustainability_milestone",
          title: "🌱 Campus saved food this week!",
          body: `Your campus saved ${weeklyWasteSaved.toFixed(1)}kg of food through smart meal planning!`,
          data: { waste_kg: weeklyWasteSaved, college_id }
        }));
        await supabase.from("notifications").insert(notifications);
      }
    }

    return successResponse({
      date,
      total_enrolled: totalEnrolled,
      predictions,
      weekly_waste_saved: weeklyWasteSaved,
    });

  } catch (err) {
    return errorResponse(err.message, 500);
  }
});
