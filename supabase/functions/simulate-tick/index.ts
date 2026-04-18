// Moves drivers slightly toward their target (assigned pickup business or origin)
// and advances pickup statuses. Called from the client every few seconds.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function step(curr: number, target: number, maxDelta: number) {
  const diff = target - curr;
  if (Math.abs(diff) <= maxDelta) return target;
  return curr + Math.sign(diff) * maxDelta;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Global pause check
  const { data: pauseRow } = await supabase
    .from("app_settings")
    .select("value")
    .eq("key", "simulation_paused")
    .maybeSingle();

  if (pauseRow?.value === true) {
    return new Response(JSON.stringify({ ok: true, paused: true, ticked: 0 }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const [{ data: drivers }, { data: pickups }, { data: businesses }, { data: shelters }] =
    await Promise.all([
      supabase.from("drivers").select("*"),
      supabase.from("pickups").select("*"),
      supabase.from("businesses").select("*"),
      supabase.from("shelters").select("*"),
    ]);

  if (!drivers || !pickups || !businesses || !shelters) {
    return new Response(JSON.stringify({ error: "fetch failed" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const STEP = 0.0025; // ~250m per tick
  const updates: Promise<unknown>[] = [];

  for (const d of drivers) {
    if (d.status === "offline") continue;
    const job = pickups.find(
      (p) => p.driver_id === d.id && (p.status === "claimed" || p.status === "in_transit"),
    );
    if (!job) continue;

    const biz = businesses.find((b) => b.id === job.business_id);
    const shelter = shelters.find((s) => s.id === job.shelter_id);
    if (!biz || !shelter) continue;

    // claimed → head to business; in_transit → head to shelter
    const target = job.status === "claimed" ? biz : shelter;
    const newLat = step(d.lat, target.lat, STEP);
    const newLng = step(d.lng, target.lng, STEP);

    updates.push(
      supabase.from("drivers").update({ lat: newLat, lng: newLng, status: "en_route" }).eq("id", d.id),
    );

    const reached = newLat === target.lat && newLng === target.lng;
    if (reached) {
      if (job.status === "claimed") {
        updates.push(supabase.from("pickups").update({ status: "in_transit" }).eq("id", job.id));
      } else {
        updates.push(supabase.from("pickups").update({ status: "delivered" }).eq("id", job.id));
        updates.push(supabase.from("drivers").update({ status: "available" }).eq("id", d.id));
      }
    }
  }

  await Promise.all(updates);

  return new Response(JSON.stringify({ ok: true, ticked: updates.length }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
