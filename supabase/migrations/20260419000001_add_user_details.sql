-- Add additional user details columns to app_users
ALTER TABLE public.app_users 
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS address TEXT,
  ADD COLUMN IF NOT EXISTS vehicle_type TEXT,
  ADD COLUMN IF NOT EXISTS capacity TEXT;

-- Update RLS to allow public insert/update for these new columns, as public inserts are allowed
-- Already covered by "Public read app_users" and standard public policies if they exist.
-- If we need to explicitly allow public insert/update to app_users:
DROP POLICY IF EXISTS "Public insert app_users" ON public.app_users;
CREATE POLICY "Public insert app_users" ON public.app_users FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Public update app_users" ON public.app_users;
CREATE POLICY "Public update app_users" ON public.app_users FOR UPDATE USING (true);
