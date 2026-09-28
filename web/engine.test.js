// The browser scorer must agree with the gno one. Same fixtures, same answers.
// Run: node web/engine.test.js
import * as e from "./engine.js";

let failures = 0;
const check = (ok, msg) => { if (!ok) { console.error("FAIL", msg); failures++; } };
const s = (secret, guess) => e.encode(e.score(secret, guess));

// Copied from p/moul/gnordle's table, every one a case a single-pass
// implementation gets wrong.
for (const [secret, guess, want] of [
  ["crane", "crane", "22222"],
  ["crane", "spilt", "00000"],
  ["crane", "erpnc", "12021"],
  ["crane", "eerie", "00102"],
  ["loyal", "lolly", "22101"],
  ["llama", "lolly", "20100"],
  ["abbey", "babes", "11220"],
  ["loyal", "alloy", "11111"],
  ["eerie", "crane", "01002"],
]) check(s(secret, guess) === want, `${secret}/${guess}: got ${s(secret, guess)}, want ${want}`);

check(s("crane", "eerie") !== s("eerie", "crane"), "scoring is not symmetric");
check(e.solved(e.score("crane", "crane")), "an exact guess is solved");
check(!e.solved(e.score("crane", "crank")), "a near miss is not");

for (const bad of ["", "cran", "cranes", "CRANE", "cran3", "cra e"])
  check(e.score("crane", bad) === null, `accepted ${JSON.stringify(bad)}`);
check(e.normalize("  CRANE ") === "crane", "normalize trims and lowercases");
check(e.emoji(e.score("loyal", "alloy")) === "🟨🟨🟨🟨🟨", "emoji row");

// Hard mode, against "cargo" after guessing "crane".
check(e.hardMode([], "cargo", "crane") === null, "nothing known yet");
check(/position 1/.test(e.hardMode(["crane"], "cargo", "brand")), "a found position must stay");
check(/contains r/.test(e.hardMode(["crane"], "cargo", "click")), "a known letter must be reused");
check(e.hardMode(["crane"], "cargo", "carry") === null, "a consistent guess is allowed");
check(e.hardMode(["unity"], "cargo", "carry") === null, "a guess that missed constrains nothing");

console.log(failures === 0 ? "ok  engine.js agrees with the gno fixtures" : `FAIL ${failures} check(s)`);
process.exit(failures === 0 ? 0 : 1);
