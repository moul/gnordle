package gnordle

import (
	"chain/runtime"
	"chain/runtime/unsafe"
	"strings"

	"gno.land/p/moul/gnordle/v0"
	"gno.land/p/moul/md/v0"
	"gno.land/p/moul/txlink/v0"
)

// self is this realm's gnoweb prefix, read from the package path it is running
// under, because the same source is deployed here and at /preview and a
// hardcoded link would point the preview back at production.
func self() string {
	return strings.TrimPrefix(unsafe.CurrentRealm().PkgPath(), runtime.ChainDomain())
}

// Render is the product: the whole game is playable from gnoweb, with no wallet
// and no JavaScript.
//
// Deterministic. It reads no current height and never rotates the puzzle;
// rotation happens on a write. A Render that advanced the day it was rendering
// would change its own output between two identical reads.
func Render(path string) string {
	switch {
	case path == "":
		return renderToday()
	case path == "about":
		return renderAbout()
	case path == "archive":
		return renderArchive()
	case strings.HasPrefix(path, "u/"):
		return renderPlayer(strings.TrimPrefix(path, "u/"))
	}
	return "# Not found\n\nNo page at `" + md.EscapeText(path) + "`. [Back to today](" + self() + ").\n"
}

func renderToday() string {
	var b strings.Builder
	b.WriteString("# Round " + itoa(round) + "\n\n")
	b.WriteString(md.Bold("Today's word is `"+answer+"`.") + " Yes, it is printed here.\n\n")
	b.WriteString("A realm cannot keep a secret from anybody willing to read a chain, so this one " +
		"does not pretend to. What it can do is " + md.Bold("prove how you played") + ": hard mode is " +
		"enforced on chain, so a letter you have already found has to stay where you found it and a " +
		"letter you know is in the word has to appear in every later guess. Your streak is a proof, " +
		"not a claim.\n\n")
	b.WriteString(itoa(entered) + " have played this round, " + itoa(solved) + " have solved it, " +
		"in at most " + itoa(MaxGuesses) + " guesses each. A round lasts " + itoa(BlocksPerDay) +
		" blocks.\n\n")

	b.WriteString(md.H2("Play"))
	b.WriteString("<gno-form>\n<gno-input name=\"word\" placeholder=\"five letters\" />\n</gno-form>\n\n")
	b.WriteString(md.Link("Or open the guess form", txlink.Call("Guess")) + "\n\n")

	if entered > 0 {
		b.WriteString(md.H2("This round"))
		b.WriteString("| player | guesses | solved |\n|---|---|---|\n")
		prefix := itoa(round) + "/"
		boards.Iterate(prefix, prefix+"~", func(k string, v any) bool {
			bd := v.(*Board)
			addr := address(k[len(prefix):])
			// The emoji rows, never the words. Everyone can read the answer
			// anyway, but a spectator page that lists other people's guesses in
			// order is a page that plays the game for you.
			rows := strings.ReplaceAll(strings.TrimSuffix(gnordle.Share(bd.Guesses, answer), "\n"), "\n", " ")
			b.WriteString("| " + player(addr) + " | " + rows + " | " + yesno(bd.Solved) + " |\n")
			return false
		})
		b.WriteString("\n")
	}

	b.WriteString(md.H2("Streaks"))
	if players.Size() == 0 {
		b.WriteString("Nobody has played yet.\n\n")
	} else {
		b.WriteString("| player | played | solved | streak | best |\n|---|---|---|---|---|\n")
		players.Iterate("", "", func(k string, v any) bool {
			p := v.(*Player)
			b.WriteString("| " + player(address(k)) + " | " + itoa(p.Played) + " | " + itoa(p.Wins) +
				" | " + itoa(p.Streak) + " | " + itoa(p.Best) + " |\n")
			return false
		})
		b.WriteString("\n")
	}

	b.WriteString(md.HorizontalRule())
	b.WriteString(md.CollapsibleSection("Guessing from a terminal", howTo()))
	b.WriteString("\n" + md.Link("Past rounds", self()+":archive") + " · " +
		md.Link("Why the answer is public", self()+":about") + "\n")
	return b.String()
}

func renderArchive() string {
	var b strings.Builder
	b.WriteString("# Past rounds\n\n")
	if len(archive) == 0 {
		b.WriteString("None yet: round " + itoa(round) + " is the first.\n\n")
	} else {
		b.WriteString("| round | word | played | solved | ended at height |\n|---|---|---|---|---|\n")
		for _, r := range archive {
			b.WriteString("| " + itoa(r.N) + " | `" + r.Word + "` | " + itoa(r.Players) + " | " +
				itoa(r.Solvers) + " | " + itoa64(r.Ended) + " |\n")
		}
		b.WriteString("\nThe last " + itoa(ArchiveKept) + " rounds only. An unbounded archive is a " +
			"page that renders slower every day and storage nobody ever reclaims.\n\n")
	}
	b.WriteString(md.Link("Back to today", self()) + "\n")
	return b.String()
}

func renderPlayer(raw string) string {
	addr := address(raw)
	if !addr.IsValid() {
		return "# Not a player\n\n`" + md.EscapeText(raw) + "` is not an address. [Back to today](" + self() + ").\n"
	}
	played, wins, streak, best := StandingOf(addr)
	guesses, isSolved := BoardOf(round, addr)

	var b strings.Builder
	b.WriteString("# " + short(addr) + "\n\n")
	b.WriteString(md.Link(addr.String(), "/u/"+addr.String()) + "\n\n")
	b.WriteString(itoa(played) + " rounds played, " + itoa(wins) + " solved. Streak " +
		md.Bold(itoa(streak)) + ", best " + itoa(best) + ".\n\n")

	b.WriteString(md.H2("Round " + itoa(round)))
	if len(guesses) == 0 {
		b.WriteString("Not started.\n\n")
	} else {
		// Their own board, with the letters, because the guesses are public
		// transaction arguments: pretending otherwise would be theatre.
		b.WriteString(gnordle.Image(guesses, answer, true, "board") + "\n\n")
		b.WriteString(md.CodeBlock(gnordle.Share(guesses, answer)))
		b.WriteString("\n" + yesno(isSolved) + "\n\n")
	}
	b.WriteString(md.Link("Back to today", self()) + "\n")
	return b.String()
}

func renderAbout() string {
	return `# Why the answer is public

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

There are two deployments of this same source: this one, and a ` + "`r/moul/preview/gnordle`" + `
flagged ` + "`private = true`" + ` so it stays redeployable while the design
is still moving. A public path can never be redeployed.

The repository, the checklist and the other three:
[github.com/moul/gnordle](https://github.com/moul/gnordle).

` + md.Link("Back to today", self()) + "\n"
}

func player(addr address) string {
	if addr == "" {
		return "_nobody_"
	}
	return md.Link(short(addr), self()+":u/"+addr.String())
}

func short(addr address) string {
	s := addr.String()
	if len(s) <= 12 {
		return s
	}
	return s[:8] + "…" + s[len(s)-4:]
}

func howTo() string {
	pkg := runtime.ChainDomain() + strings.TrimPrefix(self(), "/")
	return "```sh\n" +
		"gnokey maketx call -pkgpath " + pkg + " -func Guess -args crane \\\n" +
		"  -gas-fee 1000000ugnot -gas-wanted 3000000 -broadcast \\\n" +
		"  -chainid " + runtime.ChainID() + " -remote https://rpc.gno.land:443 YOURKEY\n" +
		"```\n" +
		"\nThe call returns five digits: 2 in place, 1 in the word, 0 not in it. " +
		"That gas number is a starting point, not a measurement: drop `-broadcast` and " +
		"the node answers with what the call actually costs.\n"
}
