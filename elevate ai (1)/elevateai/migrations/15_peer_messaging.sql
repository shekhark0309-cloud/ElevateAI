-- =============================================================================
-- ElevateAI — Peer Messaging Module
-- File: migrations/15_peer_messaging.sql
-- =============================================================================

-- 1. Conversations Table
CREATE TABLE IF NOT EXISTS conversations (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_a_id    UUID REFERENCES student_profiles(id) ON DELETE CASCADE,
  student_b_id    UUID REFERENCES student_profiles(id) ON DELETE CASCADE,
  last_message    TEXT,
  last_message_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(student_a_id, student_b_id),
  CHECK (student_a_id < student_b_id) -- Ensure consistent ordering for unique constraint
);

-- 2. Messages Table
CREATE TABLE IF NOT EXISTS messages (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id       UUID REFERENCES student_profiles(id) ON DELETE CASCADE,
  content         TEXT NOT NULL,
  is_read         BOOLEAN DEFAULT FALSE,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Enable RLS
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies for Conversations
CREATE POLICY "Users can view their conversations" ON conversations
  FOR SELECT USING (auth.uid() = student_a_id OR auth.uid() = student_b_id);

CREATE POLICY "Users can insert conversations" ON conversations
  FOR INSERT WITH CHECK (auth.uid() = student_a_id OR auth.uid() = student_b_id);

-- 5. RLS Policies for Messages
CREATE POLICY "Users can view messages in their conversations" ON messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM conversations
      WHERE id = messages.conversation_id
        AND (student_a_id = auth.uid() OR student_b_id = auth.uid())
    )
  );

CREATE POLICY "Users can send messages to their conversations" ON messages
  FOR INSERT WITH CHECK (
    sender_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM conversations
      WHERE id = messages.conversation_id
        AND (student_a_id = auth.uid() OR student_b_id = auth.uid())
    )
  );

-- 6. Trigger to update conversation last message
CREATE OR REPLACE FUNCTION update_conversation_on_new_message()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE conversations
  SET last_message = NEW.content,
      last_message_at = NEW.created_at,
      updated_at = NOW()
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_new_message
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION update_conversation_on_new_message();

-- 7. Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE conversations;
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
