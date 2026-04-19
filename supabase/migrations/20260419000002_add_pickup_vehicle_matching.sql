-- Add vehicle-matching columns to pickups table
-- required_vehicle will be auto-computed from food weight at insert time
ALTER TABLE public.pickups 
  ADD COLUMN IF NOT EXISTS required_vehicle TEXT DEFAULT '2-wheeler',
  ADD COLUMN IF NOT EXISTS assigned_driver_id UUID REFERENCES public.app_users(id),
  ADD COLUMN IF NOT EXISTS weight_kg NUMERIC DEFAULT 0;

-- Index for fast matching queries (find unassigned pickups by vehicle requirement)
CREATE INDEX IF NOT EXISTS idx_pickups_matching 
  ON public.pickups (status, required_vehicle) 
  WHERE assigned_driver_id IS NULL;

-- Index for driver lookup by vehicle type
CREATE INDEX IF NOT EXISTS idx_app_users_vehicle 
  ON public.app_users (role, vehicle_type) 
  WHERE role = 'volunteer';

-- Remove the UNIQUE constraint on email to allow same email across roles
-- (A person could be both a restaurant owner and a volunteer)
ALTER TABLE public.app_users DROP CONSTRAINT IF EXISTS app_users_email_key;
-- Replace with a composite unique: one email per role
ALTER TABLE public.app_users ADD CONSTRAINT app_users_email_role_key UNIQUE (email, role);
