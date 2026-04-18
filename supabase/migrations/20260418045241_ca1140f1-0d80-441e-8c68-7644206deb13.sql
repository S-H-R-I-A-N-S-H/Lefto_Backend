CREATE TABLE public.app_settings (
  key text PRIMARY KEY,
  value jsonb NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read app_settings"
  ON public.app_settings FOR SELECT
  USING (true);

CREATE POLICY "Public update app_settings"
  ON public.app_settings FOR UPDATE
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Public insert app_settings"
  ON public.app_settings FOR INSERT
  WITH CHECK (true);

INSERT INTO public.app_settings (key, value)
  VALUES ('simulation_paused', 'false'::jsonb)
  ON CONFLICT (key) DO NOTHING;

ALTER PUBLICATION supabase_realtime ADD TABLE public.app_settings;
ALTER TABLE public.app_settings REPLICA IDENTITY FULL;