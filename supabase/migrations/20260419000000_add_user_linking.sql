-- Users table to track app users
CREATE TABLE public.app_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('restaurant', 'volunteer', 'ngo')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Link businesses to users (restaurants own businesses)
ALTER TABLE public.businesses ADD COLUMN user_id UUID REFERENCES public.app_users(id) ON DELETE CASCADE;

-- Link shelters to users (NGOs own shelters)
ALTER TABLE public.shelters ADD COLUMN user_id UUID REFERENCES public.app_users(id) ON DELETE CASCADE;

-- Add user_id to pickups for tracking which user created the request
ALTER TABLE public.pickups ADD COLUMN user_id UUID REFERENCES public.app_users(id) ON DELETE CASCADE;

-- Add user_id to drivers for volunteer tracking
ALTER TABLE public.drivers ADD COLUMN user_id UUID REFERENCES public.app_users(id) ON DELETE CASCADE;

-- Enable RLS on app_users
ALTER TABLE public.app_users ENABLE ROW LEVEL SECURITY;

-- Users can view all users (needed for public display)
CREATE POLICY "Public read app_users" ON public.app_users FOR SELECT USING (true);

-- Update businesses RLS to filter by user
DROP POLICY "Public read businesses" ON public.businesses;
CREATE POLICY "Public read businesses" ON public.businesses FOR SELECT USING (true);

-- Update shelters RLS to filter by user
DROP POLICY "Public read shelters" ON public.shelters;
CREATE POLICY "Public read shelters" ON public.shelters FOR SELECT USING (true);

-- Update pickups RLS to allow filtering by user
DROP POLICY "Public read pickups" ON public.pickups;
CREATE POLICY "Public read pickups" ON public.pickups FOR SELECT USING (true);

-- Update drivers RLS
DROP POLICY "Public read drivers" ON public.drivers;
CREATE POLICY "Public read drivers" ON public.drivers FOR SELECT USING (true);

-- Allow public inserts for businesses linked to users
DROP POLICY "Public insert businesses" ON public.businesses;
CREATE POLICY "Public insert businesses" ON public.businesses FOR INSERT 
WITH CHECK (user_id IS NOT NULL);

-- Allow public inserts for shelters linked to users
ALTER TABLE public.shelters ADD POLICY IF NOT EXISTS "Public insert shelters" FOR INSERT 
WITH CHECK (user_id IS NOT NULL);

-- Allow public inserts for pickups linked to users
DROP POLICY "Public insert pickups" ON public.pickups;
CREATE POLICY "Public insert pickups" ON public.pickups FOR INSERT 
WITH CHECK (user_id IS NOT NULL);

-- Allow public inserts for drivers linked to users
ALTER TABLE public.drivers ADD POLICY IF NOT EXISTS "Public insert drivers" FOR INSERT 
WITH CHECK (user_id IS NOT NULL);

-- Update-at trigger for app_users
CREATE TRIGGER trg_app_users_touch BEFORE UPDATE ON public.app_users
FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- Realtime for app_users
ALTER TABLE public.app_users REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.app_users;