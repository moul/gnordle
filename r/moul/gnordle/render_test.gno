package gnordle

import (
	"strings"
	"testing"

	"gno.land/p/nt/uassert/v0"
)

// fixture plays one deterministic round.
//
// Deterministic is the operative word: Render reads no current height, never
// rotates, and every number on the page came from a write. Two identical reads
// produce identical bytes, which is what lets the pins below be exact.
func fixture(cur realm, t *testing.T) {
	t.Helper()
	reset()
	testing.SetRealm(testing.NewUserRealm(alice))
	Guess(cross(cur), "crane")
	testing.SetRealm(testing.NewUserRealm(alice))
	Guess(cross(cur), "carry")
	testing.SetRealm(testing.NewUserRealm(bob))
	Guess(cross(cur), "cargo")
}

func pinnedPaths() []string {
	return []string{"", "archive", "u/" + alice.String(), "about", "nope"}
}

// renderForPin strips the inline board, which is base64 and would make the pin
// unreadable. The SVG is asserted by shape in the engine's own tests.
func renderForPin(path string) string {
	out := Render(path)
	start := strings.Index(out, "![")
	if start < 0 {
		return out
	}
	end := strings.Index(out[start:], ")")
	if end < 0 {
		return out
	}
	return out[:start] + "<board>" + out[start+end+1:]
}

type pinnedPage struct{ path, want string }

// pinnedPages is generated: `make repin` rewrites it from what Render actually
// produces, and the diff is the review. A gno raw string literal cannot contain
// a backtick and these pages contain fenced code, so {BT} stands in for one.
var pinnedPages = []pinnedPage{
	{"", `# Round 1

**Today's word is {BT}cargo{BT}.** Yes, it is printed here.

A realm cannot keep a secret from anybody willing to read a chain, so this one does not pretend to. What it can do is **prove how you played**: hard mode is enforced on chain, so a letter you have already found has to stay where you found it and a letter you know is in the word has to appear in every later guess. Your streak is a proof, not a claim.

2 have played this round, 1 have solved it, in at most 6 guesses each. A round lasts 17280 blocks.

## Play
<gno-form>
<gno-input name="word" placeholder="five letters" />
</gno-form>

[Or open the guess form](/r/moul/gnordle$help&func=Guess)

## This round
| player | guesses | solved |
|---|---|---|
| [g1v9kxjc…40gh](/r/moul/gnordle:u/g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh) | 🟩🟨🟨⬛⬛ 🟩🟩🟩⬛⬛ | no |
| [g1vfhkyh…vdhu](/r/moul/gnordle:u/g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu) | 🟩🟩🟩🟩🟩 | yes |

## Streaks
| player | played | solved | streak | best |
|---|---|---|---|---|
| [g1v9kxjc…40gh](/r/moul/gnordle:u/g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh) | 1 | 0 | 0 | 0 |
| [g1vfhkyh…vdhu](/r/moul/gnordle:u/g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu) | 1 | 1 | 1 | 1 |

---
<details><summary>Guessing from a terminal</summary>

{BT}{BT}{BT}sh
gnokey maketx call -pkgpath gno.landr/moul/gnordle -func Guess -args crane \
  -gas-fee 1000000ugnot -gas-wanted 3000000 -broadcast \
  -chainid dev -remote https://rpc.gno.land:443 YOURKEY
{BT}{BT}{BT}

The call returns five digits: 2 in place, 1 in the word, 0 not in it. That gas number is a starting point, not a measurement: drop {BT}-broadcast{BT} and the node answers with what the call actually costs.

</details>

[Past rounds](/r/moul/gnordle:archive) · [Why the answer is public](/r/moul/gnordle:about)
`},
	{"archive", `# Past rounds

None yet: round 1 is the first.

[Back to today](/r/moul/gnordle)
`},
	{"u/g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh", `# g1v9kxjc…40gh

[g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh](/u/g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh)

1 rounds played, 0 solved. Streak **0**, best 0.

## Round 1
<board>

{BT}{BT}{BT}
🟩🟨🟨⬛⬛
🟩🟩🟩⬛⬛

{BT}{BT}{BT}

no

[Back to today](/r/moul/gnordle)
`},
	{"about", `# Why the answer is public

One of four small applications written to answer a single question: **what does a
web2.5 application on gno.land actually have to get right?** This one took the
hidden-state corner, and the finding is negative.

A realm cannot keep a secret. Its source is public the moment it is deployed, and
every derivation available to it (the round number, a height, a caller, a hash of
any of those) is derivable by anybody who can read a chain. An unexported variable
is obscurity against one query interface, not secrecy against a reader, and
building a game on it would mean claiming a property the system does not have.

Three things would actually work, and each is a bigger commitment than the game:

1. **Commit and reveal**, with somebody off chain holding the word and revealing
   it at the end of the round. That introduces an operator who can stop the game.
2. **A verifiable random function**, which gno.land does not have today.
3. **A trusted oracle realm**, which relocates the problem rather than solving it.

So the answer is printed at the top of the page, and the game is rebuilt on what a
chain is genuinely good at: **verifying**. Hard mode is enforced here. A letter you
have already found must stay where you found it, and a letter you know is in the
word must appear in every later guess. No client-side game can offer that, and no
player can fake it. Your streak is a proof.

There are two deployments of this same source: this one, and a {BT}r/moul/preview/gnordle{BT}
flagged {BT}private = true{BT} so it stays redeployable while the design
is still moving. A public path can never be redeployed.

The repository, the checklist and the other three:
[github.com/moul/gnordle](https://github.com/moul/gnordle).

[Back to today](/r/moul/gnordle)
`},
	{"nope", `# Not found

No page at {BT}nope{BT}. [Back to today](/r/moul/gnordle).
`},
}

func TestRenderIsPinned(cur realm, t *testing.T) {
	fixture(cur, t)
	if len(pinnedPages) != len(pinnedPaths()) {
		t.Fatalf("pins are stale: %d pinned, %d paths. Run `make repin`.",
			len(pinnedPages), len(pinnedPaths()))
	}
	for _, p := range pinnedPages {
		uassert.Equal(t, strings.ReplaceAll(p.want, "{BT}", "\x60"), renderForPin(p.path),
			"page "+p.path+" changed. If you meant it, run `make repin` and read the diff.")
	}
}

func TestRenderAboutMentionsThePrivateFlag(cur realm, t *testing.T) {
	out := Render("about")
	uassert.True(t, strings.Contains(out, "private = true"))
	uassert.True(t, strings.Contains(out, "github.com/moul/gnordle"))
}
