-- =============================================================================
-- ElevateAI — Base Seed Data
-- File: migrations/03_base_seed_data.sql
-- =============================================================================

-- 1. Colleges
INSERT INTO colleges (id, name, short_name, domain, state, is_verified)
VALUES
  ('c1000000-0000-0000-0000-000000000001', 'Indian Institute of Technology, Bombay', 'IIT Bombay', 'iitb.ac.in', 'Maharashtra', TRUE),
  ('c1000000-0000-0000-0000-000000000002', 'National Institute of Technology, Trichy', 'NIT Trichy', 'nitt.edu', 'Tamil Nadu', TRUE),
  ('c1000000-0000-0000-0000-000000000003', 'Delhi Technological University', 'DTU', 'dtu.ac.in', 'Delhi', TRUE),
  ('c1000000-0000-0000-0000-000000000004', 'Vellore Institute of Technology, Bhopal', 'VIT Bhopal', 'vitbhopal.ac.in', 'Madhya Pradesh', TRUE),
  ('c1000000-0000-0000-0000-000000000005', 'Birla Institute of Technology and Science, Pilani', 'BITS Pilani', 'bits-pilani.ac.in', 'Rajasthan', TRUE),
  ('c1000000-0000-0000-0000-000000000006', 'Vellore Institute of Technology, Vellore', 'VIT Vellore', 'vit.ac.in', 'Tamil Nadu', TRUE)
ON CONFLICT (id) DO NOTHING;

-- 2. Skill Badges
INSERT INTO skill_badges (name, slug, category, level, xp_value, description)
VALUES
  ('Python Developer', 'python-dev', 'technical', 1, 100, 'Foundational Python programming skills.'),
  ('Flutter Specialist', 'flutter-specialist', 'technical', 2, 250, 'Cross-platform mobile development with Flutter and Dart.'),
  ('React Master', 'react-master', 'technical', 2, 250, 'Advanced React.js and state management.'),
  ('SQL Expert', 'sql-expert', 'technical', 2, 200, 'Complex queries, schema design, and performance tuning.'),
  ('Data Structures & Algorithms', 'dsa-pro', 'technical', 3, 400, 'Advanced problem solving and algorithmic efficiency.'),
  ('UX Visionary', 'ux-visionary', 'technical', 2, 200, 'Human-centered design and prototyping.'),
  ('Strategic Leader', 'strategic-leader', 'leadership', 3, 500, 'Proven ability to lead complex team projects.'),
  ('Public Speaking', 'public-speaking', 'soft_skills', 2, 150, 'Confidence and clarity in presenting ideas to an audience.'),
  ('Community Champion', 'community-champion', 'community', 1, 150, 'Active contribution to student communities.')
ON CONFLICT (slug) DO NOTHING;

-- 3. Opportunities (Sample)
INSERT INTO opportunities (title, type, organizer_name, description, prize_amount, apply_deadline, required_skills, is_featured, is_verified)
VALUES
  ('Smart India Hackathon 2025', 'hackathon', 'Ministry of Education', 'National level hackathon to solve pressing problems.', 100000, '2025-08-30', ARRAY['Problem Solving', 'Software Development'], TRUE, TRUE),
  ('Flipkart GRiD 6.0', 'competition', 'Flipkart', 'Technical challenge for engineering students across India.', 150000, '2025-09-15', ARRAY['Competitive Programming', 'Robotics'], TRUE, TRUE),
  ('Google Step Internship', 'internship', 'Google', 'Internship program for second-year undergraduate students.', 50000, '2025-10-15', ARRAY['Data Structures', 'Algorithms'], TRUE, TRUE),
  ('Microsoft Engage 2025', 'fellowship', 'Microsoft', 'Mentorship and coding program for engineering students.', 0, '2025-06-20', ARRAY['Coding', 'Problem Solving'], TRUE, TRUE),
  ('Reliance Foundation Scholarship', 'scholarship', 'Reliance Foundation', 'Support for meritorious students from low-income backgrounds.', 200000, '2025-07-31', ARRAY['Academic Excellence'], FALSE, TRUE)
ON CONFLICT DO NOTHING;
