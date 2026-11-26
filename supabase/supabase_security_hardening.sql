CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(public.current_user_role() = 'admin', false);
$$;

CREATE OR REPLACE FUNCTION public.is_driver()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(public.current_user_role() = 'driver', false);
$$;

REVOKE ALL ON FUNCTION public.current_user_role() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_driver() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_user_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_driver() TO authenticated;

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  safe_role TEXT := 'customer';
  safe_name TEXT;
  safe_email TEXT := LOWER(TRIM(COALESCE(NEW.email, '')));
BEGIN
  -- Do NOT create a customer profile until the Gmail address is actually verified
  IF NEW.email_confirmed_at IS NULL THEN
    RETURN NEW;
  END IF;

  IF safe_email = '' OR safe_email NOT LIKE '%@gmail.com' THEN
    RETURN NEW;
  END IF;

  safe_name := COALESCE(
    NULLIF(TRIM(NEW.raw_user_meta_data->>'name'), ''),
    NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''),
    SPLIT_PART(safe_email, '@', 1)
  );

  INSERT INTO public.profiles (id, name, email, role)
  VALUES (NEW.id, safe_name, safe_email, safe_role)
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT OR UPDATE OF email_confirmed_at ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_auth_user();


CREATE OR REPLACE FUNCTION public.delete_user_by_admin(target_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Unauthorized: only admin accounts can delete users';
  END IF;

  DELETE FROM public.profiles WHERE id = target_user_id;
  DELETE FROM auth.users WHERE id = target_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_user_by_admin(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.delete_user_by_admin(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.delete_user_by_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_user_by_admin(UUID) TO service_role;


ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated read profiles" ON public.profiles;
DROP POLICY IF EXISTS "Allow anon read profiles" ON public.profiles;
DROP POLICY IF EXISTS "Allow insert update profile" ON public.profiles;
DROP POLICY IF EXISTS "Allow anon insert profiles" ON public.profiles;
DROP POLICY IF EXISTS "profiles_select_authenticated" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_own_or_admin" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own_or_admin" ON public.profiles;
DROP POLICY IF EXISTS "profiles_delete_admin" ON public.profiles;

CREATE POLICY "profiles_select_authenticated"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "profiles_insert_own_or_admin"
  ON public.profiles FOR INSERT
  TO authenticated
  WITH CHECK (
    (auth.uid() = id AND role = 'customer')
    OR public.is_admin()
  );

CREATE POLICY "profiles_update_own_or_admin"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id OR public.is_admin())
  WITH CHECK (
    (auth.uid() = id AND role = public.current_user_role())
    OR public.is_admin()
  );

CREATE POLICY "profiles_delete_admin"
  ON public.profiles FOR DELETE
  TO authenticated
  USING (public.is_admin());

-- 5. Tighten RLS on public.inventory (if table exists)
DO $$
BEGIN
  IF to_regclass('public.inventory') IS NOT NULL THEN
    ALTER TABLE public.inventory ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "inventory read" ON public.inventory;
    DROP POLICY IF EXISTS "inventory insert" ON public.inventory;
    DROP POLICY IF EXISTS "inventory update" ON public.inventory;
    DROP POLICY IF EXISTS "inventory delete" ON public.inventory;
    DROP POLICY IF EXISTS "inventory_select_authenticated" ON public.inventory;
    DROP POLICY IF EXISTS "inventory_insert_admin" ON public.inventory;
    DROP POLICY IF EXISTS "inventory_update_authenticated" ON public.inventory;
    DROP POLICY IF EXISTS "inventory_delete_admin" ON public.inventory;

    CREATE POLICY "inventory_select_authenticated"
      ON public.inventory FOR SELECT
      TO authenticated
      USING (true);

    CREATE POLICY "inventory_insert_admin"
      ON public.inventory FOR INSERT
      TO authenticated
      WITH CHECK (public.is_admin());

    CREATE POLICY "inventory_update_authenticated"
      ON public.inventory FOR UPDATE
      TO authenticated
      USING (true)
      WITH CHECK (true);

    CREATE POLICY "inventory_delete_admin"
      ON public.inventory FOR DELETE
      TO authenticated
      USING (public.is_admin());
  END IF;
END $$;


DO $$
BEGIN
  IF to_regclass('public.orders') IS NOT NULL THEN
    ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "orders_select_policy" ON public.orders;
    DROP POLICY IF EXISTS "orders_insert_policy" ON public.orders;
    DROP POLICY IF EXISTS "orders_update_policy" ON public.orders;
    DROP POLICY IF EXISTS "orders_delete_policy" ON public.orders;

    CREATE POLICY "orders_select_policy"
      ON public.orders FOR SELECT
      TO authenticated
      USING (
        public.is_admin()
        OR public.is_driver()
        OR "customerId" = auth.uid()::text
      );

    CREATE POLICY "orders_insert_policy"
      ON public.orders FOR INSERT
      TO authenticated
      WITH CHECK (
        public.is_admin()
        OR "customerId" = auth.uid()::text
      );

    CREATE POLICY "orders_update_policy"
      ON public.orders FOR UPDATE
      TO authenticated
      USING (
        public.is_admin()
        OR public.is_driver()
        OR "customerId" = auth.uid()::text
      )
      WITH CHECK (
        public.is_admin()
        OR public.is_driver()
        OR "customerId" = auth.uid()::text
      );

    CREATE POLICY "orders_delete_policy"
      ON public.orders FOR DELETE
      TO authenticated
      USING (public.is_admin());
  END IF;
END $$;

-- 7. Tighten RLS on public.driver_locations (if table exists)
DO $$
BEGIN
  IF to_regclass('public.driver_locations') IS NOT NULL THEN
    ALTER TABLE public.driver_locations ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "driver_locations read" ON public.driver_locations;
    DROP POLICY IF EXISTS "driver_locations insert" ON public.driver_locations;
    DROP POLICY IF EXISTS "driver_locations update" ON public.driver_locations;
    DROP POLICY IF EXISTS "driver_locations_select_authenticated" ON public.driver_locations;
    DROP POLICY IF EXISTS "driver_locations_insert_driver_or_admin" ON public.driver_locations;
    DROP POLICY IF EXISTS "driver_locations_update_driver_or_admin" ON public.driver_locations;

    CREATE POLICY "driver_locations_select_authenticated"
      ON public.driver_locations FOR SELECT
      TO authenticated
      USING (true);

    CREATE POLICY "driver_locations_insert_driver_or_admin"
      ON public.driver_locations FOR INSERT
      TO authenticated
      WITH CHECK (public.is_driver() OR public.is_admin());

    CREATE POLICY "driver_locations_update_driver_or_admin"
      ON public.driver_locations FOR UPDATE
      TO authenticated
      USING (public.is_driver() OR public.is_admin())
      WITH CHECK (public.is_driver() OR public.is_admin());
  END IF;
END $$;

-- 8. Tighten RLS on public.chat_messages (if table exists)
DO $$
BEGIN
  IF to_regclass('public.chat_messages') IS NOT NULL THEN
    ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Allow all users to read chat messages" ON public.chat_messages;
    DROP POLICY IF EXISTS "Allow all users to insert chat messages" ON public.chat_messages;
    DROP POLICY IF EXISTS "Allow all users to update chat messages" ON public.chat_messages;
    DROP POLICY IF EXISTS "chat_messages_select_participants" ON public.chat_messages;
    DROP POLICY IF EXISTS "chat_messages_insert_sender" ON public.chat_messages;
    DROP POLICY IF EXISTS "chat_messages_update_participants" ON public.chat_messages;

    CREATE POLICY "chat_messages_select_participants"
      ON public.chat_messages FOR SELECT
      TO authenticated
      USING (
        public.is_admin()
        OR sender_id = auth.uid()::text
        OR receiver_id = auth.uid()::text
        OR receiver_id IS NULL
        OR receiver_id = ''
      );

    CREATE POLICY "chat_messages_insert_sender"
      ON public.chat_messages FOR INSERT
      TO authenticated
      WITH CHECK (
        public.is_admin()
        OR sender_id = auth.uid()::text
      );

    CREATE POLICY "chat_messages_update_participants"
      ON public.chat_messages FOR UPDATE
      TO authenticated
      USING (
        public.is_admin()
        OR sender_id = auth.uid()::text
        OR receiver_id = auth.uid()::text
        OR receiver_id IS NULL
        OR receiver_id = ''
      );
  END IF;
END $$;

-- 9. Tighten RLS on public.delivery_issues (if table exists)
DO $$
BEGIN
  IF to_regclass('public.delivery_issues') IS NOT NULL THEN
    ALTER TABLE public.delivery_issues ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Allow all users to read delivery issues" ON public.delivery_issues;
    DROP POLICY IF EXISTS "Allow all users to insert delivery issues" ON public.delivery_issues;
    DROP POLICY IF EXISTS "Allow all users to update delivery issues" ON public.delivery_issues;
    DROP POLICY IF EXISTS "delivery_issues_select_own_or_admin" ON public.delivery_issues;
    DROP POLICY IF EXISTS "delivery_issues_insert_own_or_admin" ON public.delivery_issues;
    DROP POLICY IF EXISTS "delivery_issues_update_own_or_admin" ON public.delivery_issues;

    CREATE POLICY "delivery_issues_select_own_or_admin"
      ON public.delivery_issues FOR SELECT
      TO authenticated
      USING (
        public.is_admin()
        OR customer_id = auth.uid()::text
      );

    CREATE POLICY "delivery_issues_insert_own_or_admin"
      ON public.delivery_issues FOR INSERT
      TO authenticated
      WITH CHECK (
        public.is_admin()
        OR customer_id = auth.uid()::text
      );

    CREATE POLICY "delivery_issues_update_own_or_admin"
      ON public.delivery_issues FOR UPDATE
      TO authenticated
      USING (
        public.is_admin()
        OR customer_id = auth.uid()::text
      );
  END IF;
END $$;
