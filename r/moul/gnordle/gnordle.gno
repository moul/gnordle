// Package gnordle is a daily five-letter guessing game where the answer is
// printed at the top of the page.
//
// That is the point. This is the hidden-state corner of the exploration, and
// the finding is negative: on a transparent chain, with no VRF and no oracle,
// a realm cannot keep a secret from anybody willing to read it. Every plausible
// derivation is derivable, and an unexported variable is obscurity against one
// specific query interface rather than secrecy against a reader.
//
// So the answer is exported, deliberately, and the game is rebuilt on what a
// chain IS good at: verifying. Hard mode is enforced here, which no client-side
// game can offer and no player can fake. Your streak is a proof, not a claim.
//
// The scoring rule is [p/moul/gnordle](/p/moul/gnordle/v0), which knows nothing
// about a chain.
package gnordle

import (
	"chain/runtime"
	"errors"

	"gno.land/p/moul/gnordle/v0"
	"gno.land/p/nt/avl/v0"
)

// BlocksPerDay is how long a puzzle lasts. Blocks, not wall time, because a
// realm has no clock it can trust and a height is the only monotonic thing it
// can see. At roughly 5 second blocks this is about a day.
const BlocksPerDay = 17280

// MaxGuesses is the classic six.
const MaxGuesses = 6

// Round is one finished puzzle, kept for the archive.
type Round struct {
	N       int
	Word    string
	Players int
	Solvers int
	Ended   int64
}

// Board is one player's attempt at one puzzle.
type Board struct {
	Guesses []string
	Solved  bool
}

// Player is a standing across puzzles.
type Player struct {
	Played, Wins, Streak, Best int
	LastRound                  int
}

var (
	round     = 1
	answer    = words[0]
	roundFrom int64 // the height this round began

	boards  avl.Tree // "<round>/<address>" -> *Board
	players avl.Tree // address -> *Player
	archive []Round  // most recent first
	entered int      // players in the current round
	solved  int      // solvers in the current round
)

// ArchiveKept bounds the archive. An unbounded one is a page that renders
// slower every day and storage nobody ever reclaims.
const ArchiveKept = 30

var (
	ErrNotAWord   = errors.New("gnordle: not in the word list")
	ErrOutOfTries = errors.New("gnordle: no guesses left today")
	ErrAlready    = errors.New("gnordle: you already solved today's word")
)

// Guess plays one word. It is the only function that writes.
//
// It also rotates the puzzle, if the current one has expired. Rotation happens
// on a write and never on a read: Render must be deterministic, and a page that
// changed the state it was rendering would be both.
func Guess(cur realm, word string) string {
	caller := cur.Previous().Address()
	rotate()

	word = gnordle.Normalize(word)
	if !known(word) {
		panic(ErrNotAWord)
	}

	b := boardOf(round, caller)
	if b.Solved {
		panic(ErrAlready)
	}
	if len(b.Guesses) >= MaxGuesses {
		panic(ErrOutOfTries)
	}
	// Hard mode, enforced. This is the rule the chain can actually prove, and
	// enforcing it is what makes a streak here mean something.
	if err := gnordle.HardMode(b.Guesses, answer, word); err != nil {
		panic(err)
	}

	marks, err := gnordle.Score(answer, word)
	if err != nil {
		panic(err)
	}
	if len(b.Guesses) == 0 {
		entered++
		p := playerOf(caller)
		p.Played++
		// A missed round breaks the streak. Checked on entry rather than on
		// rotation, so no player's state depends on somebody else playing.
		if p.LastRound != 0 && p.LastRound != round-1 {
			p.Streak = 0
		}
		p.LastRound = round
	}
	b.Guesses = append(b.Guesses, word)

	if gnordle.Solved(marks) {
		b.Solved = true
		solved++
		p := playerOf(caller)
		p.Wins++
		p.Streak++
		if p.Streak > p.Best {
			p.Best = p.Streak
		}
	}
	return gnordle.Encode(marks)
}

// rotate advances the puzzle if the current one has run its blocks.
//
// The next answer is derived from the round number and the height at rotation,
// both of which are public. That is not a weakness being hidden: see the
// package comment. Nothing here pretends the result is unpredictable.
func rotate() {
	h := runtime.ChainHeight()
	if roundFrom == 0 {
		roundFrom = h
		return
	}
	for h-roundFrom >= BlocksPerDay {
		archive = append([]Round{{
			N: round, Word: answer, Players: entered, Solvers: solved, Ended: roundFrom + BlocksPerDay,
		}}, archive...)
		if len(archive) > ArchiveKept {
			archive = archive[:ArchiveKept]
		}
		roundFrom += BlocksPerDay
		round++
		entered, solved = 0, 0
		answer = words[(round*7919+int(roundFrom))%len(words)]
	}
}

// Answer returns today's word.
//
// Exported on purpose. Anyone who can reach a node can derive it from the
// source and the height anyway, so a realm that hid it behind an unexported
// variable would be claiming a secrecy it does not have. Saying it out loud is
// the honest version, and it is what makes the enforced hard mode the actual
// game.
func Answer() string { return answer }

// Today returns the current round, the height it began, and how many have
// entered and solved it.
func Today() (n int, from int64, entrants, solvers int) {
	return round, roundFrom, entered, solved
}

// BoardOf returns one player's guesses for a round. Values, not the *Board:
// this realm is private = true, and handing out a pointer into its own storage
// is the one mistake that cannot be undone afterwards.
func BoardOf(n int, addr address) (guesses []string, isSolved bool) {
	v := boards.Get(boardKey(n, addr))
	if v == nil {
		return nil, false
	}
	b := v.(*Board)
	out := make([]string, len(b.Guesses))
	copy(out, b.Guesses)
	return out, b.Solved
}

// StandingOf returns a player's record.
func StandingOf(addr address) (played, wins, streak, best int) {
	v := players.Get(addr.String())
	if v == nil {
		return 0, 0, 0, 0
	}
	p := v.(*Player)
	return p.Played, p.Wins, p.Streak, p.Best
}

// Feed returns the current round and every player in it, one per line:
//
//	round\t<n>\t<answer>\t<from>\t<entrants>\t<solvers>
//	board\t<address>\t<guess>,<guess>,...\t<solved>
func Feed() string {
	out := "round\t" + itoa(round) + "\t" + answer + "\t" + itoa64(roundFrom) + "\t" +
		itoa(entered) + "\t" + itoa(solved) + "\n"
	prefix := itoa(round) + "/"
	boards.Iterate(prefix, prefix+"~", func(k string, v any) bool {
		b := v.(*Board)
		out += "board\t" + k[len(prefix):] + "\t" + join(b.Guesses, ",") + "\t" + yesno(b.Solved) + "\n"
		return false
	})
	return out
}

// Words returns the answer pool, so a front-end can validate a guess before
// spending a transaction on one the realm will refuse.
func Words() string { return join(words, " ") }

func known(word string) bool {
	// Linear over 660 words. A sorted slice and a binary search would be five
	// times faster and is not worth the invariant: the list is edited by hand,
	// and a search that silently assumes an ordering nobody enforces is how a
	// valid word starts being rejected.
	for _, w := range words {
		if w == word {
			return true
		}
	}
	return false
}

func boardKey(n int, addr address) string { return itoa(n) + "/" + addr.String() }

func boardOf(n int, addr address) *Board {
	k := boardKey(n, addr)
	if v := boards.Get(k); v != nil {
		return v.(*Board)
	}
	b := &Board{}
	boards.Set(k, b)
	return b
}

func playerOf(addr address) *Player {
	if v := players.Get(addr.String()); v != nil {
		return v.(*Player)
	}
	p := &Player{}
	players.Set(addr.String(), p)
	return p
}

func join(items []string, sep string) string {
	out := ""
	for i, s := range items {
		if i > 0 {
			out += sep
		}
		out += s
	}
	return out
}

func yesno(b bool) string {
	if b {
		return "yes"
	}
	return "no"
}

func itoa64(n int64) string { return itoa(int(n)) }

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	neg := n < 0
	if neg {
		n = -n
	}
	out := ""
	for n > 0 {
		out = string(rune('0'+n%10)) + out
		n /= 10
	}
	if neg {
		out = "-" + out
	}
	return out
}
