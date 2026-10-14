import { readFileSync } from "node:fs";
import vm from "node:vm";
import assert from "node:assert/strict";

const html = readFileSync(new URL("../index.html", import.meta.url), "utf8");
const requiredScreens = [
  "home", "explore", "groups", "nearby", "bookings", "equipment",
  "messages", "profile", "maintenance", "earnings", "weather", "crop", "favorites", "reviews", "support"
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
  "appEquipmentList", "appOwnerList", "appMessageThreads", "weatherForm", "bookingQuantity",
  "bookingWeatherConsent", "bookingWeatherStatus", "groupMatchVillage", "groupMatchTask", "groupMatchDate",
  "maintenanceForm", "maintenanceEquipment", "appMaintenanceList", "appEarningsSummary", "appEarningsList",
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
assert.match(html, /const appDemoEquipment=\[/, "Preview examples must remain separate from live owner listings");
assert.equal((html.match(/\{type:'(?:Tractor|Rotavator|Seed drill|Sprayer)',name:/g) || []).length, 5, "Exactly five sample machines should be shown");
assert.match(html, /DEMO PREVIEW · NOT AVAILABLE FOR RENT/, "The sample panel must be unmistakably non-rentable");
assert.match(html, /illustrative UI prices/, "Demo prices must be clearly identified as illustrative");
assert.match(html, /not owner quotes or verified local rates/, "Demo prices must not be presented as market rates or owner quotes");
assert.match(html, /class="app-demo-row"/, "Sample equipment must use a separate preview-only layout");
assert.equal((html.match(/samplePrice:'₹[\d,]+'/g) || []).length, 5, "Each of the five demos must have a clearly fictional rupee price");
assert.match(html, /class="app-demo-price"/, "Demo prices must use a distinct preview style");
assert.match(html, /id="appPopularGrid"/, "Home must show the equipment preview when no live listings exist");
assert.match(html, /const homeLiveHtml=list\.length\?/, "Home must keep real owner listings ahead of demos");
assert.match(html, /homeLiveHtml\+\(list\.length\?'':demoHtml\)/, "Home demos must appear only when real listings are absent");
assert.doesNotMatch(html, /Example area · Tamil Nadu|app-demo-equipment/, "Demo preview must not imply a real listing or location");
assert.doesNotMatch(html, /seedMachines|seedGroups|Demo provider|Demo organizer/, "Production data must not seed fake owner listings");
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
assert.match(html, /Needs verification/, "Unknown specifications must remain visibly unverified");
assert.match(html, /Incompatible — listed specifications conflict/, "Known compatibility mismatches must be shown as incompatible");
assert.match(html, /id="equipImplementType"/, "Owners must be able to declare a detailed implement type");
assert.match(html, /implement_type/, "The listing flow must store and search the implement type");
assert.match(html, /id="compatibilityTask"/, "Compatibility search must be task-aware");
assert.match(html, /id="compatibilityHp"/, "Compatibility search must filter tractor horsepower");
assert.match(html, /id="compatibilityLocation"/, "Compatibility search must use the selected field location");
assert.match(html, /id="compatibilityBudget"/, "Compatibility search must expose a per-acre rate filter");
assert.match(html, /id="compatibilityDate"/, "Compatibility search must use a requested work date");
assert.match(html, /create_equipment_bundle/, "Tractor and implement requests must use the atomic bundle RPC");
assert.match(html, /create_booking_request_with_quote/, "Single bookings must save a listed-rate quantity snapshot");
assert.match(html, /requested_quantity/, "Booking history must use a saved rate quantity");
assert.match(html, /Check a weather forecast for this village/, "Booking weather lookup must require explicit user consent");
assert.match(html, /Open-Meteo only after I enable this/, "The app must disclose the weather location destination before lookup");
assert.match(html, /function updateBookingProgress\(/, "Owners must be able to share manual work progress");
assert.match(html, /booking_progress_updates/, "Booking progress must use participant-scoped Supabase rows");
assert.match(html, /function syncAppMaintenance\(/, "Owners must be able to manage real maintenance history");
assert.match(html, /equipment_maintenance_details/, "Maintenance notes and operating hours must stay in the owner-only table");
assert.match(html, /function loadAppEarnings\(/, "Completed booking earnings must be calculated from real rows");
assert.match(html, /function downloadBookingStatement\(/, "Completed bookings must support a printable work statement");
assert.match(html, /Not a payment receipt/, "Statements must not imply payment processing");
assert.match(html, /function exportBookingHistoryCsv\(/, "Users must be able to export real booking history");
assert.match(html, /Match group demand/, "Farmers must be able to filter group requests by village, task and date");
assert.match(html, /Last shared service:/, "Only opted-in maintenance dates may appear on public listing cards");
assert.match(html, /get_equipment_availability/, "Same-date availability must use the protected database function");
assert.match(html, /submit_equipment_spec_evidence/, "Owner evidence must be submitted through the ownership-checked RPC");
assert.match(html, /equipment-spec-evidence/, "Specification evidence must use the private evidence bucket");
assert.match(html, /work_type:d\.work_type/, "Group bookings must include their farm task");
assert.match(html, /booking_bundles\(task,item_count\)/, "Bundle history must display grouped requests");
assert.match(html, /requested_rate_snapshot/, "Bundle history must use saved listed-rate snapshots");
assert.match(html, /No discount is assumed/, "Bundle totals must not imply unconfigured discounts");
assert.doesNotMatch(html, /value="1200"/, "Group booking must not prefill an invented rate");


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
  "compatibility_notes", "implement_type"
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
const bundleSql = readFileSync(new URL("../supabase/smart-equipment-bundle-workflows.sql", import.meta.url), "utf8");
const bundleIndexSql = readFileSync(new URL("../supabase/smart-equipment-bundle-indexes.sql", import.meta.url), "utf8");
const operationsSql = readFileSync(new URL("../supabase/marketplace-operations-workflows.sql", import.meta.url), "utf8");
const operationsIndexSql = readFileSync(new URL("../supabase/marketplace-operations-indexes.sql", import.meta.url), "utf8");
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
assert.match(bundleSql, /implement_type/, "Detailed implement types must be additive and stored separately");
assert.doesNotMatch(bundleSql, /\bdrop\s/i, "The production feature migration must not drop existing schema objects");
assert.match(bundleSql, /booking_bundles/, "Bundle request schema must be present");
assert.match(bundleIndexSql, /booking_bundles_farmer_id_idx/, "Bundle farmer foreign keys must be indexed");
assert.match(bundleIndexSql, /equipment_spec_evidence_owner_id_idx/, "Evidence owner foreign keys must be indexed");
assert.match(bundleSql, /create_equipment_bundle/, "Atomic bundle booking function must be present");
assert.match(bundleSql, /get_equipment_availability/, "Availability privacy function must be present");
assert.match(bundleSql, /submit_equipment_spec_evidence/, "Private evidence submission function must be present");
assert.match(bundleSql, /create policy "Owners upload private equipment specification evidence"/, "Only owners may upload evidence to the private bucket");
assert.match(bundleSql, /grant execute on function public\.create_equipment_bundle[\s\S]*?to authenticated/i, "Bundle RPC must be authenticated");
assert.match(bundleSql, /revoke all on function public\.create_equipment_bundle[\s\S]*?from public, anon, authenticated/i, "Bundle RPC must not be public");
assert.match(bundleSql, /set search_path = ''/i, "Feature privileged functions must pin an empty search path");

assert.match(operationsIndexSql, /booking_progress_updates_owner_id_idx/, "Booking progress owner foreign key must be indexed");
assert.match(operationsSql, /equipment_maintenance_records/, "Owner maintenance history migration must exist");
assert.match(operationsSql, /equipment_maintenance_details/, "Private maintenance details must be stored separately");
assert.match(operationsSql, /Shared maintenance dates are public/, "Maintenance sharing must require owner opt-in");
assert.match(operationsSql, /booking_progress_updates/, "Participant-scoped booking progress migration must exist");
assert.match(operationsSql, /create_booking_request_with_quote/, "Secure quote RPC must snapshot rate unit and quantity");
assert.match(operationsSql, /security definer\s+set search_path = ''/i, "Private quote helper must pin an empty search_path");
assert.doesNotMatch(operationsSql, /\bdrop\s+(table|column|function)\b/i, "Operations migration must be additive and preserve user data");
assert.equal((bundleSql.match(/security definer\s+set search_path = ''/gi) || []).length, 5, "Feature privileged functions must all use an empty search_path");
console.log(`AgriShare static validation passed: ${requiredScreens.length} screens, ${inlineScripts.length} inline script(s), required integration markers, PWA and policy files.`);
