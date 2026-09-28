<h1 align="center">gnordle</h1>

<p align="center">
  <b>A daily word game where the answer is printed at the top of the page.</b><br>
  A realm cannot keep a secret. It can prove how you played.
</p>

<p align="center">
  <a href="https://github.com/moul/gnordle/actions/workflows/ci.yml"><img src="https://github.com/moul/gnordle/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://mygnoscan.moul.p2p.team/realm/r/moul/gnordle"><img src="https://mygnoscan.moul.p2p.team/_badges/shield/status/r/moul/gnordle?network=mainnet" alt="realm status on mainnet"></a>
  <a href="./CHECKLIST.md"><img src="https://img.shields.io/badge/web2.5-checklist-6aaa64" alt="checklist"></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-97ca00.svg" alt="License"></a>
</p>

> **This is an exploration, not a product.** One of four small applications written to
> answer a single question: *what does a web2.5 application on gno.land actually have to get
> right?* This one took **hidden state**, and the finding is negative. The decisions are
> written down in **[CHECKLIST.md](./CHECKLIST.md)**.

### ▶ [Play it](https://moul.github.io/gnordle/) &nbsp;·&nbsp; [The realm in gnoweb](https://gno.land/r/moul/gnordle) &nbsp;·&nbsp; [The checklist](./CHECKLIST.md)

---

## The finding

**A realm cannot keep a secret.** Its source is public the moment it is deployed, and every
derivation available to it (a round number, a height, a caller, a hash of any of them) is
derivable by anybody who can read a chain. An unexported variable is obscurity against one
query interface, not secrecy against a reader, and building a game on it would mean claiming
a property the system does not have.

Three things would actually work, and each is a bigger commitment than the game:

1. **Commit and reveal**, with somebody off chain holding the word. That introduces an
   operator who can stop the game.
2. **A verifiable random function**, which gno.land does not have today.
3. **A trusted oracle realm**, which relocates the problem rather than solving it.

So `Answer()` is exported, the page prints the word, and the game is rebuilt on what a chain
is genuinely good at.

## What is left, and it turns out to be the good part

**Hard mode, enforced on chain.** A letter you have already found must stay where you found
it; a letter you know is in the word must appear in every later guess. No client-side game
can offer that and no player can fake it. Your streak is a proof rather than a claim, which
is a stronger thing than a hidden answer ever was.

## The shape

```
p/moul/gnordle/v0      scoring and the hard-mode rule. no chain import, no word list.
r/moul/gnordle         the word list, the rounds, the streaks, the pages.
r/moul/gnordle/preview the same source at a second path, private = true. generated.
web/                   a static page. no build step, no node_modules.
```

**The puzzle rotates on a write, never on a read.** `Render` has to be deterministic, and a
page that advanced the day it was rendering would not be. A test pins both halves.

**Scoring is two passes, and that is the whole difficulty.** Exact positions are taken first
and spent; only then does the second pass look for letters elsewhere. A single pass gets
`alloy` against `loyal` wrong in a way that looks plausible on most words, which is why it
survives casual testing. Eight table cases pin it, in gno and again in JavaScript.

## Running it

```sh
make         # the list
make ci      # guards, lint, test: exactly what CI runs
make dev     # a local chain with these packages, at http://127.0.0.1:8888
make web     # the front-end at http://127.0.0.1:8080
make repin   # regenerate the pinned Render output, then read the diff
```

## What it does not do

**No dictionary beyond 660 words.** The answer pool is the guess pool, so a real word the
list does not have is refused. A larger list is a larger deploy and more storage, which is
the trade this repository exists to make visible.

**No timer.** A round is a number of blocks, because a realm has no clock it can trust.

## The other three

Same checklist, different pressure: [gno4](https://github.com/moul/gno4) (the chain as
referee), [gnoplace](https://github.com/moul/gnoplace) (write volume and cost),
[gnosnake](https://github.com/moul/gnosnake) (a score the chain recomputes rather than
believes).
