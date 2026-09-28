package gnordle

import (
	"strings"
	"testing"

	"gno.land/p/moul/gnordle/v0"
	"gno.land/p/nt/avl/v0"
	"gno.land/p/nt/testutils/v0"
	"gno.land/p/nt/uassert/v0"
	"gno.land/p/nt/urequire/v0"
)

var (
	alice = testutils.TestAddress("alice")
	bob   = testutils.TestAddress("bob")
)

// Every caller switch below is a literal testing.SetRealm, never a helper.
// SetRealm applies to the CURRENT FRAME: wrapped in a func it sets the helper's
// frame, the helper returns, and the caller the realm sees is unchanged. The
// call still succeeds, so the test would pass for the wrong reason.
func reset() {
	round = 1
	answer = "cargo"
	roundFrom = 0
	boards = avl.Tree{}
	players = avl.Tree{}
	archive = nil
	entered, solved = 0, 0
}

func TestGuess(cur realm, t *testing.T) {
	reset()
	testing.SetRealm(testing.NewUserRealm(alice))
	uassert.Equal(t, "21100", Guess(cross(cur), "crane"))

	guesses, isSolved := BoardOf(round, alice)
	uassert.Equal(t, 1, len(guesses))
	uassert.False(t, isSolved)

	n, _, entrants, solvers := Today()
	uassert.Equal(t, 1, n)
	uassert.Equal(t, 1, entrants)
	uassert.Equal(t, 0, solvers)
}

func TestSolving(cur realm, t *testing.T) {
	reset()
	testing.SetRealm(testing.NewUserRealm(alice))
	Guess(cross(cur), "crane")
	testing.SetRealm(testing.NewUserRealm(alice))
	uassert.Equal(t, "22222", Guess(cross(cur), "cargo"))

	_, isSolved := BoardOf(round, alice)
	uassert.True(t, isSolved)
	played, wins, streak, best := StandingOf(alice)
	uassert.Equal(t, 1, played)
	uassert.Equal(t, 1, wins)
	uassert.Equal(t, 1, streak)
	uassert.Equal(t, 1, best)

	testing.SetRealm(testing.NewUserRealm(alice))
	urequire.AbortsContains(t, cur, ErrAlready.Error(), func() {
		Guess(cross(cur), "crane")
	})
}

// Hard mode is the property this realm exists to demonstrate: the chain cannot
// hide the answer, but it can refuse a guess that throws away what you already
// knew.
func TestHardModeIsEnforced(cur realm, t *testing.T) {
	reset()
	testing.SetRealm(testing.NewUserRealm(alice))
	Guess(cross(cur), "crane") // c in place; r and a somewhere

	testing.SetRealm(testing.NewUserRealm(alice))
	urequire.AbortsContains(t, cur, "position 1", func() {
		Guess(cross(cur), "brand")
	})
	testing.SetRealm(testing.NewUserRealm(alice))
	urequire.AbortsContains(t, cur, "contains r", func() {
		Guess(cross(cur), "click")
	})
	// A refused guess costs nothing: it is not on the board.
	guesses, _ := BoardOf(round, alice)
	uassert.Equal(t, 1, len(guesses))

	testing.SetRealm(testing.NewUserRealm(alice))
	Guess(cross(cur), "carry")
	guesses, _ = BoardOf(round, alice)
	uassert.Equal(t, 2, len(guesses))
}

func TestOnlyRealWords(cur realm, t *testing.T) {
	reset()
	testing.SetRealm(testing.NewUserRealm(alice))
	urequire.AbortsContains(t, cur, ErrNotAWord.Error(), func() {
		Guess(cross(cur), "zzzzz")
	})
	testing.SetRealm(testing.NewUserRealm(alice))
	urequire.AbortsContains(t, cur, ErrNotAWord.Error(), func() {
		Guess(cross(cur), "no")
	})
	// Normalisation happens before the check, so shouting is not a rejection.
	testing.SetRealm(testing.NewUserRealm(alice))
	uassert.Equal(t, "21100", Guess(cross(cur), "  CRANE "))
}

func TestSixGuessesAndNoMore(cur realm, t *testing.T) {
	reset()
	// Six guesses that never solve it and never violate hard mode: "unity"
	// shares no letter with "cargo", so it constrains nothing.
	for i := 0; i < MaxGuesses; i++ {
		testing.SetRealm(testing.NewUserRealm(alice))
		Guess(cross(cur), "unity")
	}
	testing.SetRealm(testing.NewUserRealm(alice))
	urequire.AbortsContains(t, cur, ErrOutOfTries.Error(), func() {
		Guess(cross(cur), "unity")
	})
	_, isSolved := BoardOf(round, alice)
	uassert.False(t, isSolved)
}

// Rotation happens on a write, never on a read, so Render can be deterministic.
// This pins both halves: the round does advance, and Render never advances it.
func TestRotationHappensOnWriteOnly(cur realm, t *testing.T) {
	reset()
	testing.SetRealm(testing.NewUserRealm(alice))
	Guess(cross(cur), "crane") // anchors roundFrom
	first := answer

	testing.SkipHeights(BlocksPerDay)
	before := Render("")
	uassert.Equal(t, 1, round, "rendering did not advance the round")
	uassert.Equal(t, before, Render(""), "two identical reads, two identical pages")

	testing.SetRealm(testing.NewUserRealm(bob))
	Guess(cross(cur), "steel")
	uassert.Equal(t, 2, round)
	uassert.False(t, answer == first, "a new round has a new word")
	uassert.Equal(t, 1, len(archive))
	uassert.Equal(t, first, archive[0].Word, "the archive reveals the old word")
}

// A player who skips a round loses the streak, and one who plays every round
// keeps it. Both halves, because a streak that only ever increases is the bug.
func TestStreakBreaksOnAMissedRound(cur realm, t *testing.T) {
	reset()
	testing.SetRealm(testing.NewUserRealm(alice))
	Guess(cross(cur), "cargo") // solved round 1, streak 1

	testing.SkipHeights(BlocksPerDay)
	// Two statements, never `Guess(cross(cur), answerAfterRotation(cur))`.
	// The helper calls testing.SetRealm, and evaluating it inside the argument
	// list leaves the caller the realm sees ambiguous: alice's guess was
	// attributed elsewhere and the streak silently stopped advancing.
	next := answerAfterRotation(cur)
	testing.SetRealm(testing.NewUserRealm(alice))
	Guess(cross(cur), next) // solved round 2, streak 2
	_, _, streak, _ := StandingOf(alice)
	uassert.Equal(t, 2, streak)

	testing.SkipHeights(BlocksPerDay * 2) // two rounds go by with no play
	next = answerAfterRotation(cur)
	testing.SetRealm(testing.NewUserRealm(alice))
	Guess(cross(cur), next)
	_, _, streak, best := StandingOf(alice)
	uassert.Equal(t, 1, streak, "a skipped round breaks it, and this round restarts it")
	uassert.Equal(t, 2, best, "the best is kept")
}

// answerAfterRotation forces the pending rotation with a throwaway caller, then
// reports the new word. Tests need it because the answer changes on a write.
func answerAfterRotation(cur realm) string {
	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("rotator")))
	Guess(cross(cur), "steel")
	return answer
}

func TestFeedShape(cur realm, t *testing.T) {
	reset()
	testing.SetRealm(testing.NewUserRealm(alice))
	Guess(cross(cur), "crane")
	rows := strings.Split(strings.TrimSuffix(Feed(), "\n"), "\n")
	urequire.Equal(t, 2, len(rows))

	head := strings.Split(rows[0], "\t")
	uassert.Equal(t, 6, len(head))
	uassert.Equal(t, "round", head[0])
	uassert.Equal(t, "1", head[1])
	uassert.Equal(t, "cargo", head[2])

	board := strings.Split(rows[1], "\t")
	uassert.Equal(t, 4, len(board))
	uassert.Equal(t, "board", board[0])
	uassert.Equal(t, alice.String(), board[1])
	uassert.Equal(t, "crane", board[2])
	uassert.Equal(t, "no", board[3])

	uassert.True(t, strings.Contains(Words(), "cargo"))
}

// The answer is exported on purpose, and that is the whole finding. If somebody
// "fixes" it by unexporting it, this fails and says why.
func TestTheAnswerIsPublicOnPurpose(cur realm, t *testing.T) {
	reset()
	uassert.Equal(t, "cargo", Answer())
	uassert.True(t, strings.Contains(Render(""), "cargo"),
		"the answer is printed. A realm cannot hide it, so it does not pretend to.")
	uassert.True(t, strings.Contains(Render("about"), "Commit and reveal"))
}

func TestRenderNeverPanics(cur realm, t *testing.T) {
	reset()
	testing.SetRealm(testing.NewUserRealm(alice))
	Guess(cross(cur), "crane")
	for _, p := range []string{
		"", "about", "archive", "u/" + alice.String(), "u/", "u/nonsense",
		"nope", "../../etc/passwd", "<script>alert(1)</script>",
	} {
		uassert.True(t, len(Render(p)) > 0, "empty render for "+p)
	}
}

func TestRenderEscapesThePathItEchoes(cur realm, t *testing.T) {
	reset()
	uassert.False(t, strings.Contains(Render("u/<script>"), "<script>"))
	_ = gnordle.Length
}
