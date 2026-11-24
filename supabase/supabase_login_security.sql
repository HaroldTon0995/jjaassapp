CREATE TABLE IF NOT EXISTS public.login_attempts (
  email TEXT PRIMARY KEY,
  failed_attempts INT NOT NULL DEFAULT 0,
  locked_until TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.login_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.login_attempts FROM anon, authenticated;


CREATE OR REPLACE FUNCTION public.check_login_lockout(p_email TEXT)
RETURNS TABLE (
  remaining_seconds INT,
  failed_attempts INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email TEXT := LOWER(TRIM(COALESCE(p_email, '')));
  v_attempts INT := 0;
  v_locked_until TIMESTAMPTZ;
  v_remaining INT := 0;
BEGIN
  IF v_email = '' THEN
    RETURN QUERY SELECT 0, 0;
    RETURN;
  END IF;

  SELECT la.failed_attempts, la.locked_until
    INTO v_attempts, v_locked_until
    FROM public.login_attempts la
   WHERE la.email = v_email;

  IF NOT FOUND THEN
    RETURN QUERY SELECT 0, 0;
    RETURN;
  END IF;

  IF v_locked_until IS NOT NULL AND v_locked_until > now() THEN
    v_remaining := GREATEST(1, CEIL(EXTRACT(EPOCH FROM (v_locked_until - now())))::INT);
    RETURN QUERY SELECT v_remaining, COALESCE(v_attempts, 0);
    RETURN;
  END IF;

  IF v_locked_until IS NOT NULL AND v_locked_until <= now() THEN
    UPDATE public.login_attempts
       SET failed_attempts = 0,
           locked_until = NULL,
           updated_at = now()
     WHERE email = v_email;
    RETURN QUERY SELECT 0, 0;
    RETURN;
  END IF;

  RETURN QUERY SELECT 0, COALESCE(v_attempts, 0);
END;
$$;

CREATE OR REPLACE FUNCTION public.record_failed_login(p_email TEXT)
RETURNS TABLE (
  remaining_seconds INT,
  failed_attempts INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email TEXT := LOWER(TRIM(COALESCE(p_email, '')));
  v_attempts INT := 0;
  v_locked_until TIMESTAMPTZ;
  v_remaining INT := 0;
BEGIN
  IF v_email = '' THEN
    RETURN QUERY SELECT 0, 0;
    RETURN;
  END IF;

  UPDATE public.login_attempts
     SET failed_attempts = 0,
         locked_until = NULL,
         updated_at = now()
   WHERE email = v_email
     AND locked_until IS NOT NULL
     AND locked_until <= now();

  INSERT INTO public.login_attempts (email, failed_attempts, locked_until, updated_at)
  VALUES (v_email, 1, NULL, now())
  ON CONFLICT (email) DO UPDATE
    SET failed_attempts = public.login_attempts.failed_attempts + 1,
        updated_at = now()
  RETURNING public.login_attempts.failed_attempts, public.login_attempts.locked_until
    INTO v_attempts, v_locked_until;

  IF v_attempts >= 3 THEN
    IF v_locked_until IS NULL OR v_locked_until <= now() THEN
      v_locked_until := now() + interval '3 minutes';
      UPDATE public.login_attempts
         SET locked_until = v_locked_until,
             updated_at = now()
       WHERE email = v_email;
    END IF;
    v_remaining := GREATEST(1, CEIL(EXTRACT(EPOCH FROM (v_locked_until - now())))::INT);
  END IF;

  RETURN QUERY SELECT v_remaining, v_attempts;
END;
$$;

CREATE OR REPLACE FUNCTION public.reset_login_attempts(p_email TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email TEXT := LOWER(TRIM(COALESCE(p_email, '')));
BEGIN
  IF v_email = '' THEN
    RETURN;
  END IF;

  UPDATE public.login_attempts
     SET failed_attempts = 0,
         locked_until = NULL,
         updated_at = now()
   WHERE email = v_email;
END;
$$;

REVOKE ALL ON FUNCTION public.check_login_lockout(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_failed_login(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reset_login_attempts(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_login_lockout(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_failed_login(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reset_login_attempts(TEXT) TO anon, authenticated;
