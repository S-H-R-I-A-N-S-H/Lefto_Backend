-- Allow public inserts into businesses and pickups so the ingest edge function
-- (called from the embedded dashboard) can persist data sent via postMessage
-- from the parent page. Reads remain public; updates/deletes remain locked.

CREATE POLICY "Public insert businesses"
ON public.businesses
FOR INSERT
TO public
WITH CHECK (true);

CREATE POLICY "Public insert pickups"
ON public.pickups
FOR INSERT
TO public
WITH CHECK (true);