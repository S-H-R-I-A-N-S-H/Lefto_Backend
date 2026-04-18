-- Allow any client (including the anonymous role used by the dashboard) to push a
-- driver's live GPS coordinates without exposing a blanket UPDATE policy on the
-- drivers table. The function runs as SECURITY DEFINER so RLS is bypassed for
-- this single, narrowly-scoped operation.
CREATE OR REPLACE FUNCTION public.update_driver_location(
  _driver_id uuid,
  _lat double precision,
  _lng double precision
)
RETURNS public.drivers
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  result public.drivers;
BEGIN
  UPDATE public.drivers
     SET lat = _lat,
         lng = _lng,
         updated_at = now()
   WHERE id = _driver_id
  RETURNING * INTO result;

  IF result.id IS NULL THEN
    RAISE EXCEPTION 'Driver % not found', _driver_id USING ERRCODE = 'P0002';
  END IF;

  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_driver_location(uuid, double precision, double precision)
  TO anon, authenticated;