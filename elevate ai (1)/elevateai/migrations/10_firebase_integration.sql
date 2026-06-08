-- =============================================================================
-- ElevateAI — Firebase Integration & Notification Layer
-- File: migrations/10_firebase_integration.sql
-- =============================================================================

-- ── 1. DEVICE TOKENS TABLE ──────────────────────────────────────────────────
-- Stores Firebase Cloud Messaging (FCM) tokens for push notifications.
-- A student can have multiple devices.

CREATE TABLE IF NOT EXISTS public.device_tokens (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id      UUID NOT NULL REFERENCES public.student_profiles(id) ON DELETE CASCADE,
  fcm_token       TEXT NOT NULL UNIQUE,
  device_name     TEXT, -- e.g. "Pixel 7 Pro", "iPhone 15"
  device_os       TEXT, -- e.g. "android", "ios"
  is_active       BOOLEAN DEFAULT TRUE,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  last_seen_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can manage own device tokens"
  ON public.device_tokens FOR ALL
  USING (auth.uid() = student_id);


-- ── 2. PREFERENCE ENHANCEMENTS ──────────────────────────────────────────────
-- Add notification settings directly to student_profiles for quick access.

ALTER TABLE public.student_profiles
  ADD COLUMN IF NOT EXISTS push_enabled BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS email_enabled BOOLEAN DEFAULT TRUE;


-- ── 3. RPC FUNCTIONS ────────────────────────────────────────────────────────

-- 3A. register_device_token()
-- Called from Flutter when the app starts or token refreshes.
CREATE OR REPLACE FUNCTION public.register_device_token(
  p_fcm_token   TEXT,
  p_device_name TEXT DEFAULT NULL,
  p_device_os   TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id UUID := auth.uid();
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  INSERT INTO public.device_tokens (student_id, fcm_token, device_name, device_os, last_seen_at)
  VALUES (v_student_id, p_fcm_token, p_device_name, p_device_os, NOW())
  ON CONFLICT (fcm_token) DO UPDATE
  SET
    last_seen_at = NOW(),
    device_name = COALESCE(p_device_name, device_tokens.device_name),
    device_os = COALESCE(p_device_os, device_tokens.device_os),
    is_active = TRUE;

  RETURN jsonb_build_object('success', TRUE, 'token', p_fcm_token);
END;
$$;

GRANT EXECUTE ON FUNCTION public.register_device_token TO authenticated;


-- 3B. get_active_tokens()
-- Useful for an Edge Function to fetch tokens when sending a notification.
CREATE OR REPLACE FUNCTION public.get_active_tokens(p_student_id UUID)
RETURNS TABLE (token TEXT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT fcm_token FROM public.device_tokens
  WHERE student_id = p_student_id AND is_active = TRUE;
$$;


-- ── 4. NOTIFICATION FLYWHEEL TRIGGER ────────────────────────────────────────
-- Automatically handles logging or triggering external systems when a
-- new notification is inserted into the table.

CREATE OR REPLACE FUNCTION public.on_notification_inserted()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Here you could perform an HTTP call to a Supabase Edge Function
  -- that then sends the actual Firebase Push Notification.
  -- Example (pseudo-code):
  -- PERFORM net.http_post('https://your-project.supabase.co/functions/v1/send-push', ...);

  -- For now, we just update the 'updated_at' if we had one, or log activity.
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trigger_notification_push
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.on_notification_inserted();


-- ── 5. INDEXES ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_device_tokens_student ON public.device_tokens(student_id);
CREATE INDEX IF NOT EXISTS idx_device_tokens_active ON public.device_tokens(fcm_token) WHERE is_active = TRUE;
