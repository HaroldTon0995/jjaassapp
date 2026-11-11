-- =========================================================================
-- JJAASS Water Market - Real-Time Customer, Driver & Admin Chat Schema
-- =========================================================================

-- 1. Create chat_messages table
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL,
    order_id TEXT,
    sender_id TEXT NOT NULL,
    sender_name TEXT NOT NULL,
    sender_role TEXT NOT NULL CHECK (sender_role IN ('customer', 'driver', 'admin')),
    receiver_id TEXT,
    receiver_name TEXT,
    receiver_role TEXT,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Indexes for fast conversation retrieval and unread counters
CREATE INDEX IF NOT EXISTS idx_chat_messages_convo ON public.chat_messages (conversation_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_order ON public.chat_messages (order_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_unread ON public.chat_messages (receiver_id, is_read);

-- 3. Enable Full Replica Identity for Realtime Streaming
ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;

-- 4. Enable Row Level Security (RLS) with permissive read/write policies for authenticated and anon users
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all users to read chat messages" ON public.chat_messages;
CREATE POLICY "Allow all users to read chat messages"
    ON public.chat_messages FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Allow all users to insert chat messages" ON public.chat_messages;
CREATE POLICY "Allow all users to insert chat messages"
    ON public.chat_messages FOR INSERT
    WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all users to update chat messages" ON public.chat_messages;
CREATE POLICY "Allow all users to update chat messages"
    ON public.chat_messages FOR UPDATE
    USING (true);

-- 5. Add to supabase_realtime publication
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'chat_messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
    END IF;
END $$;
