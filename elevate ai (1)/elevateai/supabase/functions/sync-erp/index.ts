// sync-erp/index.ts — ERP Integration (configurable mock + real API stub)
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createServiceClient, successResponse, errorResponse, optionsResponse, getAuthenticatedUser } from "../_shared/utils.ts";

interface ERPData {
  student_id: string;
  attendance_pct: number;
  assignment_score: number;
  cgpa: number;
  year_of_study: number;
  course: string;
  family_income: number;
  credits_completed: number;
  backlogs: number;
  course_progress: number;
  semester_gpa: number[];
  projects: Array<{
    title: string;
    tech_stack: string[];
    role: string;
    outcome: string;
  }>;
}

async function fetchFromCollegeERP(collegeId: string, studentId: string): Promise<ERPData | null> {
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

  const year = 1 + (hash % 4);
  const semGpa = Array.from({ length: (year - 1) * 2 + 1 }, (_, i) => 7.0 + ( (hash + i) % 25 ) / 10);
  const cgpa = semGpa.reduce((a, b) => a + b, 0) / semGpa.length;

  return {
    student_id: studentId,
    attendance_pct: 75 + (hash % 20),      // 75–95%
    assignment_score: 70 + (hash % 25),    // 70–95%
    cgpa: Math.round(cgpa * 100) / 100,
    year_of_study: year,
    course: "B.Tech Computer Science",
    family_income: 300000 + (hash % 600000), // ₹3L–₹9L
    credits_completed: (year - 1) * 22 + (hash % 10),
    backlogs: (hash % 10) > 8 ? 1 : 0,
    course_progress: 20 * year + (hash % 15),
    semester_gpa: semGpa,
    projects: mockProjects.slice(0, 1 + (hash % 3))
  };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return optionsResponse();
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  const { user, error: authError } = await getAuthenticatedUser(req);
  if (authError || !user) return errorResponse(authError || "Unauthorized", 401);

  const supabase = createServiceClient();
  try {
    const { student_id, college_id } = await req.json();

    if (!student_id) return errorResponse("student_id required");

    // Security: Only allow student to sync their own record
    if (user.id !== student_id) {
      return errorResponse("Forbidden: You can only sync your own records", 403);
    }
    const erpData = await fetchFromCollegeERP(college_id ?? 'default', student_id);
    if (!erpData) return errorResponse("Failed to fetch ERP data");

    // 1. Update profile with ERP data
    const profileUpdate = {
      cgpa: erpData.cgpa,
      year_of_study: erpData.year_of_study,
      family_income: erpData.family_income,
      erp_synced: true,
      erp_credits_completed: erpData.credits_completed,
      erp_backlogs: erpData.backlogs,
      erp_course_progress: erpData.course_progress,
      erp_semester_gpa: erpData.semester_gpa,
      updated_at: new Date().toISOString()
    };

    await supabase.from('student_profiles').update(profileUpdate).eq('id', student_id);

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
        reason: "Institutional ERP Sync",
        erp_data: {
          attendance_pct: erpData.attendance_pct,
          assignment_score: erpData.assignment_score,
          semester_gpa: erpData.semester_gpa
        }
      }
    });

    // 4. Trigger DNA Recalculation
    await supabase.functions.invoke('recalculate-dna', {
      body: { student_id }
    });

    // 5. Generate Notification
    await supabase.from('notifications').insert({
      student_id,
      type: 'erp_sync_success',
      title: '✅ College Records Synced',
      body: `Your academic profile from ERP has been imported. Your TrustScore and Career Roadmap have been updated.`,
      data: { cgpa: erpData.cgpa, attendance: erpData.attendance_pct }
    });

    return successResponse({ message: "ERP sync complete", erp_data: erpData });
  } catch (e) {
    return errorResponse(e instanceof Error ? e.message : "Unexpected error", 500);
  }
});
