-- ── RLS for tables missing from migration 07 ───────────────────────────────

ALTER TABLE campus_connections    ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_preferences      ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_predictions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE dna_quiz_questions    ENABLE ROW LEVEL SECURITY;
ALTER TABLE dna_quiz_responses    ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_ideas         ENABLE ROW LEVEL SECURITY;

-- campus_connections
CREATE POLICY "Students see own connections" ON campus_connections
  FOR SELECT USING (auth.uid() IN (student_a_id, student_b_id));
CREATE POLICY "Students create connections" ON campus_connections
  FOR INSERT WITH CHECK (auth.uid() = student_a_id);
CREATE POLICY "Students update own connections" ON campus_connections
  FOR UPDATE USING (auth.uid() IN (student_a_id, student_b_id));

-- meal_preferences
CREATE POLICY "Students manage own meal prefs" ON meal_preferences
  FOR ALL USING (auth.uid() = student_id);

-- meal_predictions: read-only for all authenticated
CREATE POLICY "All can read meal predictions" ON meal_predictions
  FOR SELECT USING (auth.role() = 'authenticated');

-- dna_quiz_questions: public read
CREATE POLICY "All can read quiz questions" ON dna_quiz_questions
  FOR SELECT USING (true);

-- dna_quiz_responses
CREATE POLICY "Students manage own quiz responses" ON dna_quiz_responses
  FOR ALL USING (auth.uid() = student_id);

-- project_ideas
CREATE POLICY "Public can read project ideas" ON project_ideas
  FOR SELECT USING (true);
CREATE POLICY "Students manage own ideas" ON project_ideas
  FOR ALL USING (auth.uid() = creator_id);

-- ── Seed dna_quiz_questions (10 questions mapping to 4 archetypes) ─────────
INSERT INTO dna_quiz_questions
  (question_text, option_a, option_b, option_c, option_d,
   archetype_a, archetype_b, archetype_c, archetype_d, display_order)
VALUES
('In a group project, you naturally...',
 'Write the code and build the product',
 'Create the plan and split the tasks',
 'Design the visuals and user experience',
 'Track progress and make sure it ships',
 'Builder','Strategist','Creative','Executor', 1),

('When you hit a blocker, you...',
 'Debug it yourself and find the fix',
 'Rethink the approach from scratch',
 'Sketch an alternative flow on paper',
 'Escalate and unblock the team fast',
 'Builder','Strategist','Creative','Executor', 2),

('Your idea of a successful weekend project is...',
 'A working app or script you deployed',
 'A detailed plan with researched market sizing',
 'A polished UI prototype or design system',
 'A fully completed checklist with zero carry-overs',
 'Builder','Strategist','Creative','Executor', 3),

('Your biggest strength in a team is...',
 'Technical depth — you go deep on hard problems',
 'Big picture — you see risks others miss',
 'Aesthetic vision — you make things beautiful',
 'Reliability — you deliver what you promise',
 'Builder','Strategist','Creative','Executor', 4),

('When presenting to judges, you focus on...',
 'The technical stack and how it works',
 'The market opportunity and why now',
 'The UI and how beautiful the experience is',
 'The execution — what is done, what is next',
 'Builder','Strategist','Creative','Executor', 5),

('You learn best by...',
 'Building something and breaking it',
 'Reading case studies and frameworks',
 'Watching design walkthroughs and teardowns',
 'Following a structured course with milestones',
 'Builder','Strategist','Creative','Executor', 6),

('Your teammates would describe you as...',
 'The one who makes things actually work',
 'The one with the vision and the why',
 'The one who made it look incredible',
 'The one who kept everyone on schedule',
 'Builder','Strategist','Creative','Executor', 7),

('Your ideal role in a startup would be...',
 'CTO — building the core product',
 'CEO — setting the vision and strategy',
 'CPO/Design Lead — owning the experience',
 'COO — making operations run smoothly',
 'Builder','Strategist','Creative','Executor', 8),

('When the deadline is tomorrow and scope is too big, you...',
 'Cut non-essential features and ship a working core',
 'Renegotiate scope based on strategic priorities',
 'Ship the best-looking subset even if incomplete',
 'Stay up and finish everything that was committed',
 'Builder','Strategist','Creative','Executor', 9),

('After a hackathon loss, you first...',
 'Refactor the codebase and improve what broke',
 'Do a post-mortem on strategy and positioning',
 'Redesign the pitch deck and visual story',
 'Write a retrospective on what went wrong in execution',
 'Builder','Strategist','Creative','Executor', 10);

-- ── Realtime publication (run once on fresh project) ──────────────────────
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE trust_scores;
EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE student_dna;
EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE team_members;
EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE opportunities;
EXCEPTION WHEN others THEN NULL; END $$;
