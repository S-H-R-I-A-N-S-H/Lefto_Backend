// Edge function that ingests restaurant + surplus-food data sent from the
// parent page (the host site that embeds this dashboard via iframe).
// Two payload shapes are supported:
//   { type: "restaurant", name, address, lat, lng, closes_at? }
//   { type: "pickup", restaurant_id, food_description, quantity, expires_at, shelter_id? }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);

    if (body.type === "restaurant") {
      const { name, address, lat, lng, closes_at } = body;
      if (!name || !address || typeof lat !== "number" || typeof lng !== "number") {
        return json({ error: "Missing name, address, lat or lng" }, 400);
      }
      const { data, error } = await supabase
        .from("businesses")
        .insert({ name, address, lat, lng, closes_at: closes_at ?? "21:00:00" })
        .select()
        .single();
      if (error) throw error;
      return json({ ok: true, restaurant: data });
    }

    if (body.type === "pickup") {
      const { restaurant_id, food_description, quantity, expires_at, shelter_id } = body;
      if (!restaurant_id || !food_description || !expires_at) {
        return json({ error: "Missing restaurant_id, food_description or expires_at" }, 400);
      }

      // If parent didn't pick a shelter, choose one with the most capacity.
      let targetShelterId = shelter_id;
      if (!targetShelterId) {
        const { data: shelter } = await supabase
          .from("shelters")
          .select("id")
          .order("capacity", { ascending: false })
          .limit(1)
          .single();
        if (!shelter) return json({ error: "No shelters available" }, 400);
        targetShelterId = shelter.id;
      }

      const { data, error } = await supabase
        .from("pickups")
        .insert({
          business_id: restaurant_id,
          shelter_id: targetShelterId,
          food_description,
          quantity: quantity ?? 10,
          expires_at,
          status: "pending",
        })
        .select()
        .single();
      if (error) throw error;
      return json({ ok: true, pickup: data });
    }

    return json({ error: "Unknown type — expected 'restaurant' or 'pickup'" }, 400);
  } catch (err) {
    console.error("ingest error", err);
    return json({ error: err instanceof Error ? err.message : String(err) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
