
-- Enums
CREATE TYPE public.vehicle_type AS ENUM ('bike', 'car', 'van', 'truck');
CREATE TYPE public.driver_status AS ENUM ('available', 'en_route', 'offline');
CREATE TYPE public.pickup_status AS ENUM ('pending', 'claimed', 'in_transit', 'delivered', 'expired');

-- Businesses (food sources)
CREATE TABLE public.businesses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  closes_at TIME NOT NULL DEFAULT '21:00',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Shelters (drop-offs)
CREATE TABLE public.shelters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  capacity INT NOT NULL DEFAULT 100,
  accepts_until TIME NOT NULL DEFAULT '22:00',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Drivers (volunteers)
CREATE TABLE public.drivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  vehicle vehicle_type NOT NULL DEFAULT 'car',
  capacity INT NOT NULL DEFAULT 20,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  status driver_status NOT NULL DEFAULT 'available',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Pickups (food loads waiting/claimed)
CREATE TABLE public.pickups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  shelter_id UUID NOT NULL REFERENCES public.shelters(id) ON DELETE CASCADE,
  driver_id UUID REFERENCES public.drivers(id) ON DELETE SET NULL,
  food_description TEXT NOT NULL,
  quantity INT NOT NULL DEFAULT 10,
  expires_at TIMESTAMPTZ NOT NULL,
  status pickup_status NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_pickups_status ON public.pickups(status);
CREATE INDEX idx_pickups_driver ON public.pickups(driver_id);

-- Updated-at trigger
CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

CREATE TRIGGER trg_pickups_touch BEFORE UPDATE ON public.pickups
FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_drivers_touch BEFORE UPDATE ON public.drivers
FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- Concurrency-safe claim function (atomic, prevents double-booking)
CREATE OR REPLACE FUNCTION public.claim_pickup(_pickup_id UUID, _driver_id UUID)
RETURNS public.pickups
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  result public.pickups;
BEGIN
  UPDATE public.pickups
     SET driver_id = _driver_id,
         status = 'claimed'
   WHERE id = _pickup_id
     AND status = 'pending'
     AND driver_id IS NULL
  RETURNING * INTO result;

  IF result.id IS NULL THEN
    RAISE EXCEPTION 'Pickup % already claimed or unavailable', _pickup_id
      USING ERRCODE = 'P0001';
  END IF;

  RETURN result;
END;
$$;

-- Enable RLS — public read for the live dashboard demo
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shelters   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drivers    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pickups    ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read businesses" ON public.businesses FOR SELECT USING (true);
CREATE POLICY "Public read shelters"   ON public.shelters   FOR SELECT USING (true);
CREATE POLICY "Public read drivers"    ON public.drivers    FOR SELECT USING (true);
CREATE POLICY "Public read pickups"    ON public.pickups    FOR SELECT USING (true);

-- Realtime
ALTER TABLE public.drivers REPLICA IDENTITY FULL;
ALTER TABLE public.pickups REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.drivers;
ALTER PUBLICATION supabase_realtime ADD TABLE public.pickups;
