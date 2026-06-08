-- Run this in Supabase SQL Editor or via CLI
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('student-assets', 'student-assets', false, 5242880,  -- 5MB
   ARRAY['image/jpeg','image/png','image/webp','application/pdf']),
  ('badge-evidence', 'badge-evidence', false, 10485760,  -- 10MB
   ARRAY['image/jpeg','image/png','image/webp','application/pdf','video/mp4'])
ON CONFLICT (id) DO NOTHING;

-- RLS: Students can only access their own folder
CREATE POLICY "Students manage own assets"
  ON storage.objects FOR ALL
  USING (bucket_id = 'student-assets' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Students upload badge evidence"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'badge-evidence' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Verified badge evidence readable by all authenticated"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'badge-evidence' AND auth.role() = 'authenticated');
