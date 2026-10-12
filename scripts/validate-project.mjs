import { readFileSync } from "node:fs";
import vm from "node:vm";
import assert from "node:assert/strict";

const html = readFileSync(new URL("../index.html", import.meta.url), "utf8");
const requiredScreens = [
  "home", "explore", "groups", "nearby", "bookings", "equipment",
  "messages", "profile", "weather", "crop", "support"
];
for (const screen of requiredScreens) {
  assert.match(html, new RegExp('id="appPage-' + screen + '"'), `Missing app screen: ${screen}`);
}
for (const id of [
  "appEquipmentList", "appOwnerList", "appMessageThreads", "weatherForm",
  "cropAnalyzeForm", "nearbyPlaceForm", "appProfileAuthButton"
]) {
  assert.ok(html.includes('id="' + id + '"'), `Missing required UI element: ${id}`);
}
assert.match(html, /geocoding-api\.open-meteo\.com/, "Live location lookup should use Open-Meteo");
assert.match(html, /api\.open-meteo\.com\/v1\/forecast/, "Live weather API should be wired");
assert.match(html, /booking_messages/, "Private booking message integration should exist");
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
console.log(`AgriShare static validation passed: ${requiredScreens.length} screens, ${inlineScripts.length} inline script(s), required integration markers, PWA and policy files.`);

assert.match(html, /AgriShare visual refresh v23/, "Polished responsive app theme must be present");
assert.match(html, /prefers-reduced-motion:reduce/, "Respect reduced-motion accessibility preference");
