-- =========================================================================
-- JJAASS Water Market - Delivery Issues & Replacement Claims Schema
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.delivery_issues (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL,
    customer_id TEXT NOT NULL,
    customer_name TEXT NOT NULL,
    customer_phone TEXT,
    issue_type TEXT NOT NULL,
    affected_gallons_count INT NOT NULL DEFAULT 1,
    photo_url TEXT,
    photo_base64 TEXT,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'redeemed')),
    admin_feedback TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_delivery_issues_order ON public.delivery_issues (order_id);
CREATE INDEX IF NOT EXISTS idx_delivery_issues_customer ON public.delivery_issues (customer_id);
CREATE INDEX IF NOT EXISTS idx_delivery_issues_status ON public.delivery_issues (status);

-- Realtime
ALTER TABLE public.delivery_issues REPLICA IDENTITY FULL;
ALTER TABLE public.delivery_issues ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all users to read delivery issues" ON public.delivery_issues;
CREATE POLICY "Allow all users to read delivery issues" ON public.delivery_issues FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow all users to insert delivery issues" ON public.delivery_issues;
CREATE POLICY "Allow all users to insert delivery issues" ON public.delivery_issues FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all users to update delivery issues" ON public.delivery_issues;
CREATE POLICY "Allow all users to update delivery issues" ON public.delivery_issues FOR UPDATE USING (true);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'delivery_issues'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_issues;
    END IF;
END $$;
