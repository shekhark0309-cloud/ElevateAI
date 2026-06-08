CREATE OR REPLACE FUNCTION get_skills_overlap(student_a UUID, student_b UUID)
RETURNS INTEGER AS $$
  SELECT COUNT(*)::INTEGER
  FROM student_badges sa
  JOIN student_badges sb ON sa.badge_id = sb.badge_id
       AND sa.verify_status = 'verified'
       AND sb.verify_status = 'verified'
  WHERE sa.student_id = student_a AND sb.student_id = student_b;
$$ LANGUAGE sql STABLE SECURITY DEFINER;
