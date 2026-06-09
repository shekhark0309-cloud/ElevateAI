-- =============================================================================
-- ElevateAI — Flywheel Automation (Final Integration)
-- File: migrations/36_flywheel_automation.sql
-- =============================================================================

-- 1. Portfolio-to-Application Loop: Automatically link the latest resume version to new applications
CREATE OR REPLACE FUNCTION public.link_latest_resume_to_app()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_latest_pdf TEXT;
BEGIN
    -- Find the most recent generated resume for this student
    SELECT pdf_url INTO v_latest_pdf
    FROM public.resume_history
    WHERE student_id = NEW.student_id
    ORDER BY created_at DESC
    LIMIT 1;

    -- If a resume exists and user hasn't provided a custom one, auto-link it
    IF v_latest_pdf IS NOT NULL AND NEW.resume_url IS NULL THEN
        NEW.resume_url := v_latest_pdf;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_app_draft_link_resume ON public.opportunity_applications;
CREATE TRIGGER on_app_draft_link_resume
  BEFORE INSERT ON public.opportunity_applications
  FOR EACH ROW
  EXECUTE FUNCTION public.link_latest_resume_to_app();

-- 2. Realtime Event Notifier: Consolidated trigger for all flywheel updates
-- This allows the Frontend to listen to a single channel for "Data Refreshed" events
CREATE OR REPLACE FUNCTION public.notify_flywheel_event()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM pg_notify(
    'flywheel_update',
    json_build_object(
      'student_id', COALESCE(NEW.student_id, NEW.id, OLD.student_id),
      'table', TG_TABLE_NAME,
      'operation', TG_OP,
      'timestamp', NOW()
    )::text
  );
  RETURN NEW;
END;
$$;

-- Apply to key behavioral tables
DROP TRIGGER IF EXISTS tr_notify_trust ON public.trust_scores;
CREATE TRIGGER tr_notify_trust AFTER UPDATE ON public.trust_scores FOR EACH ROW EXECUTE FUNCTION public.notify_flywheel_event();

DROP TRIGGER IF EXISTS tr_notify_dna ON public.student_dna;
CREATE TRIGGER tr_notify_dna AFTER UPDATE ON public.student_dna FOR EACH ROW EXECUTE FUNCTION public.notify_flywheel_event();

DROP TRIGGER IF EXISTS tr_notify_notifs ON public.notifications;
CREATE TRIGGER tr_notify_notifs AFTER INSERT ON public.notifications FOR EACH ROW EXECUTE FUNCTION public.notify_flywheel_event();

-- 3. Scholarship-to-Peer Loop: Auto-notify on relevant success stories
-- (Placeholder for complex matching logic, simplified for demo)
CREATE OR REPLACE FUNCTION public.nudge_on_peer_success()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- If a student gets accepted to a major opportunity, notify peers in same college
    IF NEW.status = 'accepted' THEN
        INSERT INTO public.notifications (student_id, type, title, body, priority, category)
        SELECT id, 'peer_success', '🌟 Peer Success!',
               (SELECT full_name FROM student_profiles WHERE id = NEW.student_id) || ' just got accepted! Ask for tips.',
               'medium', 'social'
        FROM public.student_profiles
        WHERE college_id = (SELECT college_id FROM student_profiles WHERE id = NEW.student_id)
          AND id != NEW.student_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_peer_success_nudge ON public.opportunity_applications;
CREATE TRIGGER tr_peer_success_nudge
  AFTER UPDATE OF status ON public.opportunity_applications
  FOR EACH ROW
  WHEN (NEW.status = 'accepted')
  EXECUTE FUNCTION public.nudge_on_peer_success();
