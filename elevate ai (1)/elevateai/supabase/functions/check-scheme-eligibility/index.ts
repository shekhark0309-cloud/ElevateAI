// supabase/functions/check-scheme-eligibility/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import {
  createServiceClient,
  successResponse,
  errorResponse,
  optionsResponse,
} from "../_shared/utils.ts";

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return optionsResponse();

  try {
    const { student_id, scheme_id } = await req.json();
    if (!student_id || !scheme_id) return errorResponse("student_id and scheme_id are required");

    const supabase = createServiceClient();

    const { data: student } = await supabase.from("student_profiles").select("*").eq("id", student_id).single();
    const { data: scheme } = await supabase.from("schemes").select("*").eq("id", scheme_id).single();

    if (!student || !scheme) return errorResponse("Student or Scheme not found", 404);

    const missingCriteria: string[] = [];

    if (scheme.state && scheme.state !== student.state) {
      missingCriteria.push(`Requires domicile in ${scheme.state}`);
    }
    if (scheme.category && scheme.category !== student.category) {
      missingCriteria.push(`Requires ${scheme.category} category`);
    }
    if (scheme.max_income && student.family_income > scheme.max_income) {
      missingCriteria.push(`Family income exceeds limit of ₹${scheme.max_income}`);
    }
    if (scheme.min_cgpa && (student.cgpa || 0) < scheme.min_cgpa) {
      missingCriteria.push(`Requires minimum CGPA of ${scheme.min_cgpa}`);
    }

    return successResponse({
      eligible: missingCriteria.length === 0,
      missing_criteria: missingCriteria,
      details: {
        student_state: student.state,
        student_category: student.category,
        student_income: student.family_income,
        scheme_requirements: {
          state: scheme.state,
          category: scheme.category,
          max_income: scheme.max_income
        }
      }
    });
  } catch (e) {
    return errorResponse(e.message, 500);
  }
});
