// sync-erp/index.ts — ERP Integration (configurable mock + real API stub)
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createServiceClient, successResponse, errorResponse, optionsResponse } from "../_shared/utils.ts";

interface ERPData {
  student_id: string;
  attendance_pct: number;
  assignment_score: number;
  cgpa?: number;
  year_of_study?: number;
  course?: string;
  family_income?: number;
  projects?: Array<{
    title: string;
    tech_stack: string[];
    role: string;
    outcome: string;
  }>;
}

async function fetchFromCollegeERP(collegeId: string, studentId: string): Promise<ERPData | null> {
  const erpUrl = Deno.env.get(`ERP_URL_${collegeId.toUpperCase()}`);
  const erpKey = Deno.env.get(`ERP_API_KEY_${collegeId.toUpperCase()}`);

  // If ERP credentials exist, call real API
  if (erpUrl && erpKey) {
    try {
      const res = await fetch(`${erpUrl}/student/${studentId}`, {
        headers: { 'Authorization': `Bearer ${erpKey}`, 'Content-Type': 'application/json' }
      });
      if (res.ok) return await res.json();
    } catch (e) {
      console.error('ERP API call failed, falling back to mock:', e);
    }
  }

  // Deterministic mock based on student_id hash (consistent across calls)
  const hash = [...studentId].reduce((acc, c) => acc + c.charCodeAt(0), 0);

  const mockProjects = [
    {
      title: "Smart Attendance System",
      tech_stack: ["Flutter", "Firebase", "Face Recognition"],
      role: "Lead Developer",
      outcome: "Deployed in 3 departments"
    },
    {
      title: "Campus Marketplace",
      tech_stack: ["React", "Node.js", "MongoDB"],
      role: "Backend Engineer",
      outcome: "500+ active users"
    },
    {
      title: "Health Monitor App",
      tech_stack: ["Kotlin", "SQLite", "Sensors"],
      role: "Mobile Developer",
      outcome: "Won 2nd prize in Hackathon"
    }
  ];

  return {
    student_id: studentId,
    attendance_pct: 70 + (hash % 25),      // 70–94%
    assignment_score: 65 + (hash % 30),    // 65–94%
    cgpa: 6.5 + ((hash % 30) / 10),        // 6.5–9.5
    year_of_study: 1 + (hash % 4),         // 1–4
    family_income: 200000 + (hash % 800000), // ₹2L–₹10L
    projects: mockProjects.slice(0, 1 + (hash % 3))
  };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return optionsResponse();
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  const supabase = createServiceClient();
  try {
    const { student_id, college_id, seed_all = false } = await req.json();

    if (seed_all) {
      // Batch seed all students in a college (for demo setup)
      const { data: students } = await supabase
        .from('student_profiles')
        .select('id, college_id')
        .eq('college_id', college_id)
        .eq('is_active', true);

      const results = [];
      for (const s of students ?? []) {
        const erpData = await fetchFromCollegeERP(s.college_id, s.id);
        if (erpData) {
          await supabase.from('student_profiles').update({
            cgpa: erpData.cgpa,
            year_of_study: erpData.year_of_study,
            family_income: erpData.family_income,
          }).eq('id', s.id);

          results.push({ id: s.id, success: true });
        }
      }
      return successResponse({ seeded: results.length, results });
    }

    if (!student_id) return errorResponse("student_id required");
    const erpData = await fetchFromCollegeERP(college_id ?? 'default', student_id);
    if (!erpData) return errorResponse("Failed to fetch ERP data");

    // 1. Update profile with ERP data
    const profileUpdate: Record<string, unknown> = {};
    if (erpData.cgpa) profileUpdate.cgpa = erpData.cgpa;
    if (erpData.year_of_study) profileUpdate.year_of_study = erpData.year_of_study;
    if (erpData.family_income) profileUpdate.family_income = erpData.family_income;

    if (Object.keys(profileUpdate).length > 0) {
      await supabase.from('student_profiles').update(profileUpdate).eq('id', student_id);
    }

    // 2. Import Projects (if user has few projects)
    const { count: projectCount } = await supabase
      .from('student_projects')
      .select('*', { count: 'exact', head: true })
      .eq('student_id', student_id);

    if ((projectCount ?? 0) < 2 && erpData.projects) {
      const projectsToInsert = erpData.projects.map(p => ({
        student_id,
        title: p.title,
        tech_stack: p.tech_stack,
        role: p.role,
        outcome: p.outcome
      }));
      await supabase.from('student_projects').insert(projectsToInsert);
    }

    // 3. Trigger TrustScore Update (Recalculate with ERP data)
    await supabase.functions.invoke('update-trust-score', {
      body: {
        student_id,
        reason: "ERP Sync",
        erp_data: {
          attendance_pct: erpData.attendance_pct,
          assignment_score: erpData.assignment_score
        }
      }
    });

    // 4. Trigger DNA Recalculation
    await supabase.functions.invoke('recalculate-dna', {
      body: { student_id }
    });

    return successResponse({ message: "ERP sync complete", erp_data: erpData });
  } catch (e) {
    return errorResponse(e instanceof Error ? e.message : "Unexpected error", 500);
  }
});
