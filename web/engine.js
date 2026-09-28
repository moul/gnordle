// The scoring rule, in the browser: the same two passes as the gno package, so
// the page can colour a row before the transaction lands and a shared board
// renders with no chain at all.
//
// A second implementation is a second thing that can be wrong, so it is
// cross-checked against the gno package's own fixtures in engine.test.js.
export const LENGTH = 5;
export const MISS = 0, PRESENT = 1, HIT = 2;

export function score(secret, guess) {
  if (!valid(secret) || !valid(guess)) return null;
  const marks = new Array(LENGTH).fill(MISS);
  const left = new Map();
  for (let i = 0; i < LENGTH; i++) {
    if (secret[i] === guess[i]) marks[i] = HIT;
    else left.set(secret[i], (left.get(secret[i]) || 0) + 1);
  }
  for (let i = 0; i < LENGTH; i++) {
    if (marks[i] === HIT) continue;
    const n = left.get(guess[i]) || 0;
    if (n > 0) { marks[i] = PRESENT; left.set(guess[i], n - 1); }
  }
  return marks;
}

export const valid = (w) => typeof w === "string" && /^[a-z]{5}$/.test(w);
export const normalize = (w) => String(w ?? "").trim().toLowerCase();
export const solved = (marks) => marks.every((m) => m === HIT);
export const encode = (marks) => marks.join("");
export const emoji = (marks) => marks.map((m) => (m === HIT ? "🟩" : m === PRESENT ? "🟨" : "⬛")).join("");

// hardMode mirrors the on-chain rule, so the page can refuse a guess before it
// costs a transaction. The chain is still the one that decides.
export function hardMode(previous, secret, guess) {
  if (!valid(guess)) return "five letters, a to z";
  for (const p of previous) {
    const marks = score(secret, p);
    if (!marks) continue;
    for (let i = 0; i < LENGTH; i++) {
      if (marks[i] === HIT && guess[i] !== p[i])
        return `position ${i + 1} must stay ${p[i]}, you already found it`;
      if (marks[i] === PRESENT && !guess.includes(p[i]))
        return `the word contains ${p[i]}, so your guess must too`;
    }
  }
  return null;
}
