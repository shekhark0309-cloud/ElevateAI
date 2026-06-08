-- =============================================================================
-- ElevateAI — Demo Seed Data
-- File: migrations/08_demo_seed.sql
-- =============================================================================

-- 1. Additional scholarships for Scheme Simulator demo (India-specific)
INSERT INTO opportunities (title, type, organizer_name, description, prize_amount,
  apply_deadline, required_skills, is_featured, is_verified,
  eligible_states, eligible_categories, min_cgpa, max_year)
VALUES
  ('PM Scholarship Scheme (PMSS)', 'scholarship', 'Ministry of Home Affairs',
   'Scholarship for children of ex-servicemen and ex-coast guard personnel.',
   25000, NOW() + INTERVAL '45 days', ARRAY['Academic Excellence'],
   TRUE, TRUE, NULL, ARRAY['general','obc','sc','st'], 6.0, 4),
  ('Pragati Scholarship for Girls', 'scholarship', 'AICTE',
   'For girls pursuing technical education in first or second year.',
   30000, NOW() + INTERVAL '30 days', ARRAY['Academic Excellence'],
   TRUE, TRUE, NULL, ARRAY['general','obc','sc','st'], 6.0, 2),
  ('Post-Matric Scholarship for OBC Students', 'scholarship', 'Government of Madhya Pradesh',
   'Financial assistance to OBC students for pursuing higher education.',
   15000, NOW() + INTERVAL '50 days', ARRAY['Academic Excellence'],
   FALSE, TRUE, ARRAY['Madhya Pradesh'], ARRAY['obc'], 5.5, 4),
  ('NSP Central Sector Scheme', 'scholarship', 'Ministry of Education',
   'Merit-cum-means scholarship for college and university students.',
   12000, NOW() + INTERVAL '60 days', ARRAY['Academic Excellence'],
   FALSE, TRUE, NULL, NULL, 7.0, 4),
  ('Indira Gandhi Scholarship for Single Girl Child', 'scholarship', 'UGC',
   'For single girl children pursuing postgraduate education.',
   36200, NOW() + INTERVAL '20 days', ARRAY['Academic Excellence'],
   TRUE, TRUE, NULL, NULL, NULL, 4)
ON CONFLICT DO NOTHING;

-- 2. DNA quiz questions (M14)
INSERT INTO dna_quiz_questions (question_text, option_a, option_b, option_c, option_d,
  archetype_a, archetype_b, archetype_c, archetype_d, display_order)
VALUES
  ('On a group project, you naturally tend to...',
   'Start coding/building immediately', 'Create a plan and assign roles first',
   'Sketch ideas and think about user experience', 'Execute whatever the team decides efficiently',
   'Builder', 'Strategist', 'Creative', 'Executor', 1),
  ('When a project hits a major blocker, you...',
   'Hack a workaround solution', 'Reassess the entire strategy',
   'Reframe the problem creatively', 'Push through and ship anyway',
   'Builder', 'Strategist', 'Creative', 'Executor', 2),
  ('Your ideal hackathon role would be...',
   'Full-stack developer', 'Team lead and project manager',
   'UI/UX designer and storyteller', 'Operations and delivery manager',
   'Builder', 'Strategist', 'Creative', 'Executor', 3),
  ('After a setback, you first...',
   'Debug and fix the technical issue', 'Analyze what went wrong strategically',
   'Find inspiration to try a new approach', 'Get the team back on track',
   'Builder', 'Strategist', 'Creative', 'Executor', 4),
  ('Your strongest contribution to a team is...',
   'Building things that work', 'Seeing the big picture',
   'Making things beautiful and intuitive', 'Getting things done on time',
   'Builder', 'Strategist', 'Creative', 'Executor', 5),
  ('What is your preferred way to learn a new technology?',
   'Build a small project immediately', 'Read documentation and understand the architecture',
   'Experiment with design and UI possibilities', 'Follow a step-by-step tutorial',
   'Builder', 'Strategist', 'Creative', 'Executor', 6),
  ('In a brainstorming session, you are the one who...',
   'Asks if the idea can actually be built', 'Asks how it fits into the long-term goals',
   'Suggests the most "out of the box" ideas', 'Takes notes and organizes the ideas',
   'Builder', 'Strategist', 'Creative', 'Executor', 7),
  ('How do you handle messy, unorganized data?',
   'Write a script to clean it up automatically', 'Look for logical patterns and insights',
   'Visualize it to make it easier to understand', 'Sort and categorize it according to a checklist',
   'Builder', 'Strategist', 'Creative', 'Executor', 8),
  ('When working under a tight deadline, you...',
   'Focus on the core functionality only', 'Re-prioritize the roadmap to cut fluff',
   'Pivot the design for maximum impact/simplicity', 'Work methodically to ensure every task is finished',
   'Builder', 'Strategist', 'Creative', 'Executor', 9),
  ('What kind of feedback do you value most?',
   'It works perfectly and is efficient', 'Your logic and strategy were sound',
   'That is a truly unique and fresh perspective', 'You are the most reliable person on the team',
   'Builder', 'Strategist', 'Creative', 'Executor', 10),
  ('What is your workspace usually like?',
   'Tools, code snippets, and parts everywhere', 'Clean and minimalist with a whiteboard',
   'Inspirational posters, colors, and sketches', 'Very organized with clear to-do lists',
   'Builder', 'Strategist', 'Creative', 'Executor', 11),
  ('In a complex game or challenge, you prefer...',
   'Optimizing resources and mechanics', 'Outsmarting the opponent with logic',
   'Using unpredictable or artistic moves', 'Following a proven winning formula',
   'Builder', 'Strategist', 'Creative', 'Executor', 12),
  ('When starting a new hobby or project, you...',
   'Buy the gear and start doing it right away', 'Research the best techniques and theory',
   'Look for ways to personalize and customize it', 'Find a class or a guide to follow',
   'Builder', 'Strategist', 'Creative', 'Executor', 13),
  ('What is your favorite part of a project?',
   'The moment the code finally runs/it works', 'The planning and architecture phase',
   'The final polishing and visual styling', 'The satisfaction of hitting the "Submit" button',
   'Builder', 'Strategist', 'Creative', 'Executor', 14),
  ('How do you deal with ambiguous or unclear tasks?',
   'Start building prototypes to find clarity', 'Break it down into logical sub-components',
   'Explore various creative paths and metaphors', 'Ask for a clear checklist or set of rules',
   'Builder', 'Strategist', 'Creative', 'Executor', 15)
ON CONFLICT DO NOTHING;

-- 3. Campus resources for demo (M12)
INSERT INTO campus_resources (college_id, resource_type, name, capacity, is_available, location_label)
SELECT
  'c1000000-0000-0000-0000-000000000001',
  r.resource_type, r.name, r.capacity, r.is_available, r.location_label
FROM (VALUES
  ('library_seat', 'Reading Room A — Seat 12', 1, true, 'Library Block, Ground Floor'),
  ('library_seat', 'Reading Room A — Seat 13', 1, false, 'Library Block, Ground Floor'),
  ('classroom', 'Seminar Hall 201', 30, true, 'Academic Block 2, First Floor'),
  ('lab_equipment', 'Raspberry Pi Kit #3', 1, true, 'Electronics Lab, Block C')
) AS r(resource_type, name, capacity, is_available, location_label)
ON CONFLICT DO NOTHING;

-- 4. Campus TV & Radio Schedule (M2)
INSERT INTO broadcast_schedule (title, description, start_time, end_time, host_name, category)
VALUES
  ('Morning Tech Byte', 'Start your day with the latest in AI and Tech from around the world.', NOW() + INTERVAL '9 hours', NOW() + INTERVAL '10 hours', 'Arjun Verma', 'news'),
  ('Mock Interview Workshop', 'Watch a live mock interview with a senior recruiter from Google.', NOW() + INTERVAL '14 hours', NOW() + INTERVAL '15 hours', 'Dr. Shalini', 'educational'),
  ('Campus Sports Highlights', 'Catch up on all the action from the Inter-College Cricket Finals.', NOW() + INTERVAL '18 hours', NOW() + INTERVAL '19 hours', 'Kabir Singh', 'sports')
ON CONFLICT DO NOTHING;

INSERT INTO radio_shows (title, description, host_name, start_time, end_time, is_live)
VALUES
  ('Success Stories', 'Conversations with students who cracked top internships.', NOW() + INTERVAL '11 hours', NOW() + INTERVAL '12 hours', 'Priya Das', true),
  ('Exam Stress Buster', 'Relaxing music and tips to handle your semester exams.', NOW() + INTERVAL '21 hours', NOW() + INTERVAL '22 hours', 'DJ Rahul', false)
ON CONFLICT DO NOTHING;

INSERT INTO recordings (title, description, video_url, duration_seconds, category)
VALUES
  ('Introduction to Flutter', 'Master the basics of Flutter in this recorded session.', 'https://storage.elevateai.app/v1/rec/flutter_basics.mp4', 3600, 'educational'),
  ('Startup Pitching 101', 'Learn how to pitch your idea to venture capitalists.', 'https://storage.elevateai.app/v1/rec/pitching_101.mp4', 2400, 'educational')
ON CONFLICT DO NOTHING;
