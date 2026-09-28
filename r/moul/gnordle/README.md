# `gno.land/r/moul/gnordle`

**A daily five-letter guessing game where the answer is printed at the top of the page.**

That is the point. This is the **hidden-state** corner of the [web2.5
checklist](https://github.com/moul/gnordle/blob/main/CHECKLIST.md), and the finding is
negative: a realm cannot keep a secret. Its source is public the moment it is deployed, and
every derivation available to it (a round number, a height, a caller, a hash of any of them)
is derivable by anybody who can read a chain. An unexported variable is obscurity against
one query interface, not secrecy against a reader.

Three things would actually work, and each is a bigger commitment than the game: commit and
reveal with an off-chain revealer, which introduces an operator who can stop the game; a
verifiable random function, which gno.land does not have today; or a trusted oracle realm,
which relocates the problem rather than solving it.

So `Answer()` is exported, and the game is rebuilt on what a chain is genuinely good at:
**verifying**. Hard mode is enforced here. A letter you have already found must stay where
you found it; a letter you know is in the word must appear in every later guess. Your streak
is a proof rather than a claim.

**The puzzle rotates on a write, never on a read.** `Render` must be deterministic, and a
page that advanced the day it was rendering would not be. Rotation happens at the top of
`Guess`, and a test pins both halves: the round does advance, and rendering never advances
it.

**Your guesses are public transaction arguments.** The spectator page shows other players'
results as emoji rows only, which is manners rather than secrecy; your own page shows the
letters, because pretending otherwise would be theatre.

Pages: today at the root, `:archive` for past rounds, `:u/<address>` for a player, `:about`
for the finding. `Answer()`, `Today()`, `Feed()` and `Words()` are the machine-readable
views.

Source: [github.com/moul/gnordle](https://github.com/moul/gnordle).
