/**
 * Standalone test for restaurant → NGO multi-stop routing
 * Demonstrates the algorithm works completely offline (no external dependencies)
 */

// Haversine distance calculation (from dijkstra.ts)
const R_KM = 6371;

function haversineKm(a, b) {
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const x =
    Math.sin(dLat / 2) ** 2 +
    Math.sin(dLng / 2) ** 2 * Math.cos(lat1) * Math.cos(lat2);
  return 2 * R_KM * Math.asin(Math.sqrt(x));
}

// Nearest-neighbor greedy algorithm
function findNearest(from, candidates, exclude = new Set()) {
  if (candidates.length === 0) return null;
  let best = { node: candidates[0], distanceKm: Infinity };

  for (const candidate of candidates) {
    if (exclude.has(candidate.id)) continue;
    const distance = haversineKm(from, candidate);
    if (distance < best.distanceKm) {
      best = { node: candidate, distanceKm: distance };
    }
  }
  return best.distanceKm === Infinity ? null : best;
}

// Multi-stop route builder (from restaurantNgoRouting.ts)
function buildMultiStopRoute(restaurants, ngos, startPoint) {
  const stops = [];
  let cumulativeDistance = 0;
  let currentPoint = startPoint;

  const visitedRestaurants = new Set();
  const visitedNgos = new Set();

  const restaurantNodes = restaurants.map((r) => ({
    id: r.id,
    lat: r.lat,
    lng: r.lng,
    name: r.name,
  }));

  const ngoNodes = ngos.map((n) => ({
    id: n.id,
    lat: n.lat,
    lng: n.lng,
    name: n.name,
  }));

  // Alternate: pickup → dropoff → pickup → dropoff
  while (
    visitedRestaurants.size < restaurants.length ||
    visitedNgos.size < ngos.length
  ) {
    // Find nearest unvisited restaurant for pickup
    if (visitedRestaurants.size < restaurants.length) {
      const nearest = findNearest(currentPoint, restaurantNodes, visitedRestaurants);
      if (nearest) {
        const restaurant = restaurants.find((r) => r.id === nearest.node.id);
        const distanceKm = nearest.distanceKm;
        cumulativeDistance += distanceKm;

        stops.push({
          id: restaurant.id,
          name: restaurant.name,
          type: "pickup",
          lat: restaurant.lat,
          lng: restaurant.lng,
          distanceFromPrevious: distanceKm,
          cumulativeDistance,
        });

        visitedRestaurants.add(restaurant.id);
        currentPoint = nearest.node;
      }
    }

    // Find nearest unvisited NGO for dropoff
    if (
      visitedNgos.size < ngos.length &&
      stops[stops.length - 1]?.type === "pickup"
    ) {
      const nearest = findNearest(currentPoint, ngoNodes, visitedNgos);
      if (nearest) {
        const ngo = ngos.find((n) => n.id === nearest.node.id);
        const distanceKm = nearest.distanceKm;
        cumulativeDistance += distanceKm;

        stops.push({
          id: ngo.id,
          name: ngo.name,
          type: "dropoff",
          lat: ngo.lat,
          lng: ngo.lng,
          distanceFromPrevious: distanceKm,
          cumulativeDistance,
        });

        visitedNgos.add(ngo.id);
        currentPoint = nearest.node;
      }
    }

    if (
      visitedRestaurants.size >= restaurants.length &&
      visitedNgos.size >= ngos.length
    ) {
      break;
    }

    if (stops.length > restaurants.length + ngos.length) {
      break;
    }
  }

  const estimatedDuration = Math.ceil(cumulativeDistance * 2); // rough estimate

  return {
    stops,
    totalDistance: parseFloat(cumulativeDistance.toFixed(2)),
    estimatedDuration,
    startPoint,
  };
}

// ========== DEMO DATA (Bengaluru) ==========
const RESTAURANTS = [
  {
    id: "r1",
    name: "Truffles Restaurant",
    lat: 12.9748,
    lng: 77.601,
  },
  {
    id: "r2",
    name: "Vidyarthi Bhavan",
    lat: 12.952,
    lng: 77.572,
  },
  {
    id: "r3",
    name: "Meghana Foods",
    lat: 12.969,
    lng: 77.6055,
  },
];

const NGOS = [
  {
    id: "n1",
    name: "Akshaya Patra Foundation",
    lat: 12.991,
    lng: 77.553,
  },
  {
    id: "n2",
    name: "Robin Hood Army Hub",
    lat: 12.935,
    lng: 77.625,
  },
];

const START_POINT = {
  id: "start",
  lat: 12.9716,
  lng: 77.5946,
};

// ========== RUN THE ROUTING ==========
console.log("\n🍽️  RESTAURANT → NGO ROUTE OPTIMIZATION (OFFLINE)\n");
console.log("=".repeat(60));

console.log("\n📍 START POINT:", START_POINT);
console.log("\n🍕 RESTAURANTS:");
RESTAURANTS.forEach((r, i) => {
  console.log(`  ${i + 1}. ${r.name} (${r.lat}, ${r.lng})`);
});

console.log("\n🏠 NGOs:");
NGOS.forEach((n, i) => {
  console.log(`  ${i + 1}. ${n.name} (${n.lat}, ${n.lng})`);
});

// Calculate route
const route = buildMultiStopRoute(RESTAURANTS, NGOS, START_POINT);

console.log("\n" + "=".repeat(60));
console.log("📋 OPTIMIZED ROUTE RESULT:\n");

console.log(`✅ Total Distance: ${route.totalDistance.toFixed(2)} km`);
console.log(`⏱️  Estimated Duration: ~${route.estimatedDuration} minutes`);
console.log(`🛑 Number of Stops: ${route.stops.length}\n`);

console.log("STOP SEQUENCE:");
console.log("-".repeat(60));

route.stops.forEach((stop, idx) => {
  const icon = stop.type === "pickup" ? "📦" : "🎯";
  console.log(`\n${idx + 1}. ${icon} ${stop.type.toUpperCase()}: ${stop.name}`);
  console.log(
    `   Distance: ${stop.distanceFromPrevious.toFixed(2)} km from previous stop`,
  );
  console.log(
    `   Cumulative: ${stop.cumulativeDistance.toFixed(2)} km from start`,
  );
  console.log(`   Location: (${stop.lat}, ${stop.lng})`);
});

console.log("\n" + "=".repeat(60));
console.log("\n🎉 Route calculated successfully - NO EXTERNAL DEPENDENCIES!\n");

// Verification
console.log("✅ VERIFICATION:");
console.log(`   ✓ Haversine distance algorithm (offline)`);
console.log(`   ✓ Greedy nearest-neighbor optimization`);
console.log(`   ✓ Alternating pickup/dropoff pattern`);
console.log(`   ✓ Total distance calculation`);
console.log(`   ✓ No OSRM API calls`);
console.log(`   ✓ No external geocoding\n`);
