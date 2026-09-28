// The page. It knows today's answer, because the realm prints it: the board can
// therefore be coloured the instant you type, and hard mode can be refused
// before it costs a transaction. The chain remains the one that decides.
import * as e from "./engine.js";
import { NETWORKS, qevalString, wallet, gnokeyCommand } from "./chain.js";

const $ = (id) => document.getElementById(id);
const state = {
  net: NETWORKS.mainnet, netName: "mainnet", account: null,
  answer: "", round: 0, entrants: 0, solvers: 0,
  guesses: [], draft: "", words: null, boards: [],
};

function draw() {
  const rows = [];
  for (let r = 0; r < 6; r++) {
    const word = state.guesses[r] ?? (r === state.guesses.length ? state.draft : "");
    const scored = r < state.guesses.length && state.answer ? e.score(state.answer, word) : null;
    const tiles = [];
    for (let i = 0; i < 5; i++) {
      const cls = scored ? ["miss", "present", "hit"][scored[i]] : "";
      tiles.push(`<div class="tile ${cls}">${word[i] ?? ""}</div>`);
    }
    rows.push(`<div class="row">${tiles.join("")}</div>`);
  }
  $("board").innerHTML = rows.join("");
}

const say = (msg, cls = "") => { const s = $("status"); s.textContent = msg; s.className = `status ${cls}`; };
const warn = (msg) => { $("msg").textContent = msg || ""; };

async function refresh() {
  try {
    const feed = (await qevalString(state.net, "Feed()")).split("\n").filter(Boolean).map((r) => r.split("\t"));
    const head = feed.find((r) => r[0] === "round");
    if (!head) throw new Error("no round in the feed");
    state.round = Number(head[1]);
    state.answer = head[2];
    state.entrants = Number(head[4]);
    state.solvers = Number(head[5]);
    state.boards = feed.filter((r) => r[0] === "board").map((r) => ({ who: r[1], guesses: r[2] ? r[2].split(",") : [], solved: r[3] === "yes" }));
    const mine = state.account && state.boards.find((b) => b.who === state.account);
    state.guesses = mine ? mine.guesses : [];

    $("today").innerHTML = `Round <b>${state.round}</b>. The answer is <b>${state.answer}</b>. ` +
      `${state.entrants} played, ${state.solvers} solved.`;
    $("streaks").innerHTML = state.boards.length
      ? state.boards.map((b) => `<div>${b.who.slice(0, 8)}… ${e.emoji(e.score(state.answer, b.guesses[b.guesses.length - 1] ?? "aaaaa") ?? [])} ${b.solved ? "✓" : ""}</div>`).join("")
      : `<p class="fine">Nobody has played this round.</p>`;
    say(`round ${state.round} on ${state.netName}`, "live");
    draw();
  } catch (err) {
    // Not deployed on this network yet is a normal state for a repository whose
    // whole subject is the deploy story. An empty panel reads as "still
    // loading" forever, so say what happened instead.
    $("today").innerHTML = `<p class="fine">Nothing to read here: the realm is not deployed on this network yet, or the node did not answer.</p>`;
    $("streaks").innerHTML = "";
    say(`${state.netName}: ${err.message}`, "bad");
  }
  if (state.words === null) {
    try { state.words = new Set((await qevalString(state.net, "Words()")).split(" ")); } catch { state.words = null; }
  }
}

$("guess-form").addEventListener("submit", async (ev) => {
  ev.preventDefault();
  const word = e.normalize($("guess").value);
  warn("");
  if (!e.valid(word)) return warn("five letters, a to z");
  if (state.words && !state.words.has(word)) return warn("not in the word list");
  // Refused here so it never costs a transaction. The chain enforces the same
  // rule; this is a courtesy, not the authority.
  const why = state.answer ? e.hardMode(state.guesses, state.answer, word) : null;
  if (why) return warn(why);
  if (!state.account) return warn("connect a wallet to play, or paste the command below");
  try {
    say("signing…");
    await wallet.call(state.net, state.account, "Guess", [word]);
    $("guess").value = "";
    state.draft = "";
    say("sent — waiting for the block", "live");
    setTimeout(refresh, 1500);
  } catch (err) { warn(err.message); say("refused", "bad"); }
});

$("guess").addEventListener("input", (ev) => { state.draft = e.normalize(ev.target.value); draw(); });

document.addEventListener("click", async (ev) => {
  const t = ev.target;
  if (t.id === "reload") return refresh();
  if (t.id === "share") {
    const text = `gnordle ${state.round} ${state.guesses.length}/6\n` +
      state.guesses.map((g) => e.emoji(e.score(state.answer, g))).join("\n");
    await navigator.clipboard.writeText(text);
    say("result copied — no letters in it", "live");
  }
  if (t.id === "connect") {
    try { state.account = await wallet.connect(); say(`connected ${state.account.slice(0, 10)}…`, "live"); refresh(); }
    catch (err) { say(err.message, "bad"); }
  }
});

$("network").addEventListener("change", (ev) => {
  state.netName = ev.target.value;
  state.net = NETWORKS[state.netName];
  state.words = null;
  $("link-realm").href = `https://gno.land/${state.net.realm.replace("gno.land/", "")}`;
  $("cmd").textContent = gnokeyCommand(state.net, "Guess", ["<word>"]);
  refresh();
});

$("cmd").textContent = gnokeyCommand(state.net, "Guess", ["<word>"]);
draw();
refresh();
