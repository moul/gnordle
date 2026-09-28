# `gno.land/p/moul/gnordle/v0`

**The scoring rule of a five-letter guessing game**: `Score`, `Solved`, `HardMode`, `Valid`, `Emoji`, `Board`.

```go
import "gno.land/p/moul/gnordle/v0"

marks, _ := gnordle.Score("cargo", "crane")  // c in place, r and a elsewhere
gnordle.Encode(marks)                        // -> "21100"
gnordle.Emoji(marks)                         // -> 🟩🟨🟨⬛⬛
gnordle.HardMode([]string{"crane"}, "cargo", "click")
// -> error: the word contains r, so your guess must too
```

No word list, no state, no chain import. It takes a secret and a guess and says how close
they are.

**The whole difficulty is repeated letters, and it is settled in two passes.** Exact
positions are taken first and their letters are spent; only then does the second pass look
for letters elsewhere, drawing from what the first left. A single pass gets `alloy` against
`loyal` wrong, and gets it wrong in a way that looks plausible on most words, which is
exactly why it survives casual testing. Eight table cases pin it, and scoring is
deliberately asymmetric: `Score(a, b)` is not `Score(b, a)`.

**`HardMode` is the reason this package is interesting on a chain.** A realm cannot keep a
secret from anybody willing to read it, but it can prove that every guess was consistent
with what the player already knew: a letter found in place stays in place, a letter known to
be in the word appears in every later guess. No client-side game can offer that, and no
player can fake it. The error names the specific rule that was broken, because "invalid
guess" with three tries left is worse than no rule at all.

Two more behaviours worth knowing:

- **`Score` refuses a bad secret as loudly as a bad guess**, so a realm that somehow stored
  a five-character non-word cannot silently score every guess against it.
- **`Board` takes a `reveal` flag.** A board still in play draws colours and no letters;
  drawing them is how a spectator page becomes a spoiler, and a realm page has spectators
  by default.

Live demo: [r/moul/gnordle](/r/moul/gnordle).
