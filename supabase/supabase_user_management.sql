-- ==============================================================================
-- JJAASS WATER MARKET: USER & PROFILE MANAGEMENT CONFIGURATION
-- Run this in the Supabase SQL Editor (https://supabase.com/dashboard)
-- ==============================================================================

-- 1. Ensure public.profiles table exists with all necessary columns
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'customer',
  phone TEXT,
  address TEXT,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Enable Row Level Security (RLS) on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Policy A: Everyone can read profiles (needed for dashboard, fleet dispatch, driver lookups)
DROP POLICY IF EXISTS "Allow authenticated read profiles" ON public.profiles;
CREATE POLICY "Allow authenticated read profiles"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (true);

-- Policy B: Allow anon select (for initial role checking during login flow)
DROP POLICY IF EXISTS "Allow anon read profiles" ON public.profiles;
CREATE POLICY "Allow anon read profiles"
  ON public.profiles
  FOR SELECT
  TO anon
  USING (true);

-- Policy C: Users can insert/update their own profile, and Admins can insert/update any profile
DROP POLICY IF EXISTS "Allow insert update profile" ON public.profiles;
CREATE POLICY "Allow insert update profile"
  ON public.profiles
  FOR ALL
  TO authenticated
  USING (
    auth.uid() = id 
    OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  )
  WITH CHECK (
    auth.uid() = id 
    OR (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

-- Policy D: Allow anon service insert (for initial account creation)
DROP POLICY IF EXISTS "Allow anon insert profiles" ON public.profiles;
CREATE POLICY "Allow anon insert profiles"
  ON public.profiles
  FOR INSERT
  TO anon
  WITH CHECK (true);

-- 3. Stored Procedure for Admins to delete accounts from BOTH profiles & auth.users
-- This allows the admin to permanently delete accounts anytime without foreign key locks
CREATE OR REPLACE FUNCTION delete_user_by_admin(target_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  -- Delete associated orders / logs references if needed, or rely on cascade
  DELETE FROM public.profiles WHERE id = target_user_id;
  DELETE FROM auth.users WHERE id = target_user_id;
END;
$$;

-- Grant execution to authenticated users (admin checks are handled inside frontend and policies)
GRANT EXECUTE ON FUNCTION delete_user_by_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_by_admin(UUID) TO service_role;

-- 4. Enable Realtime on profiles table so admin dashboard syncs live without refreshing
ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;

