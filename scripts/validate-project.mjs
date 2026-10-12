import { readFileSync } from "node:fs";
import vm from "node:vm";
import assert from "node:assert/strict";

const html = readFileSync(new URL("../index.html", import.meta.url), "utf8");
const requiredScreens = [
  "home", "explore", "groups", "nearby", "bookings", "equipment",
  "messages", "profile", "weather", "crop", "favorites", "reviews", "support"
];
for (const screen of requiredScreens) {
  assert.match(html, new RegExp('id="appPage-' + screen + '"'), `Missing app screen: ${screen}`);
}

const navMarkupToken = '<nav class="app-bottom-nav"';
assert.equal(html.split(navMarkupToken).length - 1, 1, "There must be only one active bottom navigation bar");
const navStart = html.indexOf(navMarkupToken);
const navEnd = html.indexOf("</nav>", navStart);
assert.ok(navEnd > navStart, "Bottom navigation must be closed");
const bottomNav = html.slice(navStart, navEnd);
const navScreens = ["home", "explore", "bookings", "profile"];
let previousNavPosition = -1;
for (const screen of navScreens) {
  const position = bottomNav.indexOf('data-screen="' + screen + '"');
  assert.ok(position > previousNavPosition, "Bottom navigation order must match the app layout around the central add action");
  previousNavPosition = position;
}
const navEmojis = ["🏠", "🔍", "📅", "👤"];
previousNavPosition = -1;
for (const emoji of navEmojis) {
  const position = bottomNav.indexOf(emoji);
  assert.ok(position > previousNavPosition, "Primary navigation must use the intended emoji icons");
  previousNavPosition = position;
}
assert.ok(bottomNav.includes('aria-label="List equipment"'), "The center add action needs a clear accessible name");
assert.ok(!html.includes('aria-label="Quick navigation"'), "The obsolete duplicate navigation must not return");
assert.ok(html.includes('id="appProfileAuthButton"'), "The profile must provide an account action");
assert.ok(html.includes("function syncAppAuthState("), "Auth state changes must refresh the app UI");
assert.ok(html.includes("btn.textContent=currentUser?'↪️ Sign out':'🔑 Sign in / Create account'"), "Profile account action must clearly show sign-in or sign-out");
assert.ok(html.includes(`<button class="app-icon-btn" aria-label="Messages" title="Messages" onclick="showAppScreen('messages')">💬</button>`), "The messages shortcut must open messages");
assert.ok(html.includes(`<button class="app-icon-btn" aria-label="Notifications" title="Notifications" onclick="showAppScreen('profile')">🔔</button>`), "The notifications shortcut must open the profile notification panel");
assert.ok(html.includes(`<button onclick="showAppScreen('messages')"><span class="menu-icon">💬</span>Messages`), "Profile menu must provide direct access to messages");
assert.ok(!html.includes(">Account settings"), "Do not present a settings action that only reopens sign-in");
assert.ok(html.includes('<span class="menu-icon">📅</span>My bookings'), "Profile bookings action needs a clear emoji");
assert.ok(html.includes('<span class="menu-icon">🤝</span>Group bookings'), "Profile group action needs a clear emoji");
assert.ok(html.includes(".app-bottom-nav button:focus-visible"), "Navigation needs a visible keyboard focus state");
assert.ok(html.includes(".app-bottom-nav button{font-size:10px}"), "Small-screen navigation labels must remain readable");
for (const id of [
  "appEquipmentList", "appOwnerList", "appMessageThreads", "weatherForm",
  "cropAnalyzeForm", "nearbyPlaceForm", "appProfileAuthButton",
  "cropImageConsent", "appSupportForm", "appFavoritesList", "appReviewList"
]) {
  assert.ok(html.includes('id="' + id + '"'), `Missing required UI element: ${id}`);
}
assert.match(html, /geocoding-api\.open-meteo\.com/, "Live location lookup should use Open-Meteo");
assert.match(html, /api\.open-meteo\.com\/v1\/forecast/, "Live weather API should be wired");
assert.match(html, /booking_messages/, "Private booking message integration should exist");
assert.match(html, /function safeEquipmentImage\(/, "Listing photos must be restricted to the trusted Supabase Storage bucket");
assert.match(html, /function toggleFavorite\(/, "Equipment favorites must work");
assert.match(html, /async function loadAppReviews\(/, "Completed booking reviews must be available");
assert.match(html, /from\('support_requests'\)/, "Private support submission must use Supabase");
assert.match(html, /cropImageConsent/, "Crop photos must require explicit endpoint consent");
assert.doesNotMatch(html, /seedMachines|seedGroups|Demo provider|Demo organizer/, "Production UI source must not retain fake listing fixtures");
assert.match(html, /Identity not independently verified/, "Provider identity limitations must be visible");
assert.match(html, /Payments & wallet · Coming soon/, "Payments must be clearly unavailable until implemented");
assert.match(html, /owner_id/, "Equipment owner IDs must be retained for owner actions");
assert.match(html, /async function changeGroupStatus\(/, "Group status handler must be async");
assert.match(html, /async function loadAppBookings\(/, "Booking history must load asynchronously");
assert.match(html, /async function openBookingConversation\(/, "Booking messages must load asynchronously");
assert.match(html, /function editEquipment\(/, "Owners must be able to edit their own equipment");
assert.match(html, /function deleteEquipment\(/, "Owners must be able to delete their own equipment");
assert.match(html, /async function loadAppNotifications\(/, "Profile must load real notifications");
assert.match(html, /id="cropAnalyzeForm"/, "CropSight screen must expose a real-image analysis form");
assert.match(html, /id="compatibilityTractor"/, "Compatibility matching must allow selection of a real tractor listing");
assert.match(html, /function renderCompatibilityMatches\(/, "Compatibility matching logic must exist");
assert.match(html, /horsepower/, "Equipment form must store declared horsepower");
assert.match(html, /required_pto_rpm/, "Equipment form must store required PTO speed");
assert.match(html, /required_hydraulic_lpm/, "Equipment form must store implement hydraulic requirements");
assert.match(html, /Manual compatibility review required/, "Unknown specifications must not be reported as confirmed matches");

assert.match(html, /No scan performed/, "Crop analysis must state clearly when no prediction has been made");

assert.doesNotMatch(html, /image:x\.image_url\|\|['"]https:\/\/images\.unsplash\.com/, "Equipment data must not use generic photo URLs as listing images");
assert.doesNotMatch(html, /Verified provider|Identity verified/, "Do not claim provider identity verification from the listing flag alone");

const inlineScripts = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)]
  .filter(([, attrs]) => !/\bsrc\s*=/.test(attrs))
  .map(([, , source]) => source)
  .filter(source => source.trim());
assert.ok(inlineScripts.length > 0, "Expected application JavaScript");
for (let i = 0; i < inlineScripts.length; i++) {
  new vm.Script(inlineScripts[i], { filename: `index-inline-${i + 1}.js` });
}
for (const path of ["manifest.json", "sw.js", "privacy.html", "terms.html"]) {
  readFileSync(new URL("../" + path, import.meta.url), "utf8");
}
const schema = readFileSync(new URL("../supabase/schema.sql", import.meta.url), "utf8");
const equipmentWriteGrants = [...schema.matchAll(/grant\s+(insert|update)\s*\(([^)]+)\)\s*on table public\.equipment/gi)];
const expectedEquipmentWriteColumns = [
  "equipment_role", "horsepower", "hitch_type", "pto_rpm", "hydraulic_capacity_lpm",
  "min_tractor_hp", "max_tractor_hp", "required_pto_rpm", "required_hydraulic_lpm",
  "compatibility_notes"
];
for (const operation of ["insert", "update"]) {
  const grant = equipmentWriteGrants.find(([, action]) => action.toLowerCase() === operation);
  assert.ok(grant, `Missing equipment ${operation} column grant`);
  const columns = new Set(grant[2].split(",").map(column => column.trim().toLowerCase()));
  for (const column of expectedEquipmentWriteColumns) {
    assert.ok(columns.has(column), `Equipment ${operation} grant is missing ${column}`);
  }
  assert.ok(!columns.has("verified"), "Equipment owners must not be able to grant themselves verification");
}

const workflowSql = readFileSync(new URL("../supabase/production-readiness-workflows.sql", import.meta.url), "utf8");
const indexSql = readFileSync(new URL("../supabase/production-readiness-indexes.sql", import.meta.url), "utf8");
assert.match(workflowSql, /booking_requests_active_equipment_date_uidx/, "Active equipment booking collisions must be prevented in Postgres");
assert.match(indexSql, /booking_reviews_reviewer_created_idx/, "Review participant lookups must be indexed");
assert.match(indexSql, /support_requests_equipment_id_idx/, "Support listing lookups and the foreign key must be indexed");
assert.match(workflowSql, /support_requests/, "Private support queue migration must exist");
assert.match(workflowSql, /booking_reviews/, "Participant-only review workflow must exist");
assert.match(workflowSql, /grant insert \(requester_id, request_type, equipment_id, details\)[\s\S]*?on public\.support_requests to authenticated/i, "Support requests must grant authenticated insert only");
assert.match(workflowSql, /private\.can_submit_booking_review/, "Review writes must be checked against a completed participant booking");
assert.equal((workflowSql.match(/security definer\s+set search_path = ''/gi) || []).length, 2, "New privileged functions must use an empty search_path");
assert.match(schema, /security definer\s+set search_path = ''/i, "Starter schema privileged functions must pin an empty search_path");
console.log(`AgriShare static validation passed: ${requiredScreens.length} screens, ${inlineScripts.length} inline script(s), required integration markers, PWA and policy files.`);
