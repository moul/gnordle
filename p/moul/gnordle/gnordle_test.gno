package gnordle

import (
	"strings"
	"testing"

	"gno.land/p/nt/uassert/v0"
	"gno.land/p/nt/urequire/v0"
)

// marks renders a result as digits so a table can state the expected answer in
// one readable string. uassert type-switches on the concrete type and [Length]Mark
// matches no case, so comparing the arrays directly would report "unsupported
// type" and pass for any pair.
func marks(t *testing.T, secret, guess string) string {
	t.Helper()
	m, err := Score(secret, guess)
	urequire.NoError(t, err)
	return Encode(m)
}

// Repeated letters are the whole difficulty of this game, and every case below
// is one a single-pass implementation gets wrong.
func TestScore(t *testing.T) {
	cases := []struct{ name, secret, guess, want string }{
		{"exact", "crane", "crane", "22222"},
		{"nothing at all", "crane", "spilt", "00000"},
		{"one letter placed, three elsewhere", "crane", "erpnc", "12021"},

		{"one e in the secret, two in the guess: the placed one takes it",
			"crane", "eerie", "00102"},
		{"three l in the guess, two in the secret, one of them placed",
			"loyal", "lolly", "22101"},
		{"three l in the guess, two in the secret, the first is a hit",
			"llama", "lolly", "20100"},
		{"a letter spent by a hit is not present again elsewhere",
			"abbey", "babes", "11220"},
		{"an anagram: every letter present, none in place",
			"loyal", "alloy", "11111"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			uassert.Equal(t, tc.want, marks(t, tc.secret, tc.guess))
		})
	}
}

// Scoring is not symmetric, and assuming it is produces a plausible-looking
// wrong answer. Pinned so nobody "simplifies" it into one.
func TestScoreIsNotSymmetric(t *testing.T) {
	uassert.Equal(t, "00102", marks(t, "crane", "eerie"))
	uassert.Equal(t, "01002", marks(t, "eerie", "crane"))
}

func TestSolved(t *testing.T) {
	m, err := Score("crane", "crane")
	urequire.NoError(t, err)
	uassert.True(t, Solved(m))

	m, err = Score("crane", "crank")
	urequire.NoError(t, err)
	uassert.False(t, Solved(m))
}

func TestValid(t *testing.T) {
	cases := []struct {
		name, word string
		want       error
	}{
		{"five lowercase letters", "crane", nil},
		{"too short", "cran", ErrLength},
		{"too long", "cranes", ErrLength},
		{"empty", "", ErrLength},
		{"uppercase is not normalised here", "CRANE", ErrAlphabet},
		{"a digit", "cran3", ErrAlphabet},
		{"a space", "cra e", ErrAlphabet},
		{"not ascii", "crané", ErrLength},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := Valid(tc.word)
			if tc.want == nil {
				uassert.NoError(t, err)
				return
			}
			uassert.ErrorIs(t, err, tc.want)
		})
	}
}

// Score refuses a bad secret as loudly as a bad guess. A realm that somehow
// stored a five-character non-word would otherwise score every guess against
// it silently.
func TestScoreRefusesBothSides(t *testing.T) {
	_, err := Score("crane", "nope")
	uassert.ErrorIs(t, err, ErrLength)
	_, err = Score("nope", "crane")
	uassert.ErrorIs(t, err, ErrLength)
}

func TestNormalize(t *testing.T) {
	uassert.Equal(t, "crane", Normalize("  CRANE "))
	uassert.Equal(t, "crane", Normalize("Crane"))
}

func TestEmojiHidesTheLetters(t *testing.T) {
	m, err := Score("loyal", "alloy")
	urequire.NoError(t, err)
	uassert.Equal(t, "🟨🟨🟨🟨🟨", Emoji(m))
	uassert.Equal(t, "11111", Encode(m))
}

func TestShareIsOneRowPerGuess(t *testing.T) {
	out := Share([]string{"alloy", "loyal"}, "loyal")
	uassert.Equal(t, 2, len(strings.Split(strings.TrimSuffix(out, "\n"), "\n")))
	uassert.False(t, strings.Contains(out, "loyal"), "a shared result names no word")
}

// A board still in play draws colours and no letters. Drawing them is how a
// spectator page becomes a spoiler, and a realm page has spectators by default.
func TestBoardHidesLettersUntilRevealed(t *testing.T) {
	hidden := Board([]string{"crane"}, "loyal", false)
	shown := Board([]string{"crane"}, "loyal", true)
	uassert.Equal(t, 0, strings.Count(hidden, "<text"))
	uassert.Equal(t, Length, strings.Count(shown, "<text"))
	uassert.Equal(t, strings.Count(hidden, "<rect"), strings.Count(shown, "<rect"))
}

func TestBoardIsAlwaysSixRows(t *testing.T) {
	for _, n := range []int{0, 1, 3, 6} {
		guesses := make([]string, n)
		for i := range guesses {
			guesses[i] = "crane"
		}
		s := Board(guesses, "loyal", true)
		uassert.Equal(t, rows*Length, strings.Count(s, "<rect"))
	}
}

func TestImageIsAnSvgDataURI(t *testing.T) {
	img := Image([]string{"crane"}, "loyal", true, "board")
	uassert.True(t, strings.HasPrefix(img, "![board](data:image/svg+xml;base64,"), img[:60])
}

// Hard mode is the rule a transparent chain is actually good at: it cannot keep
// the answer from anybody, but it can prove every guess was consistent with what
// the player already knew.
func TestHardMode(t *testing.T) {
	cases := []struct {
		name     string
		previous []string
		guess    string
		wantErr  bool
		contains string
	}{
		{"nothing known yet", nil, "crane", false, ""},
		{"a position already found must stay", []string{"crane"}, "brand", true, "position 1"},
		{"...and keeping it is fine", []string{"crane"}, "carry", false, ""},
		{"a letter known to be in the word must be reused", []string{"crane"}, "click", true, "contains r"},
		{"a guess where everything missed constrains nothing", []string{"unity"}, "carry", false, ""},
		{"and it is still five letters", []string{"crane"}, "cran", true, ""},
	}
	// The secret is "cargo" throughout, so "crane" reveals: c in place, and both
	// r and a somewhere in the word.
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := HardMode(tc.previous, "cargo", tc.guess)
			if !tc.wantErr {
				uassert.NoError(t, err)
				return
			}
			urequire.Error(t, err)
			if tc.contains != "" {
				uassert.True(t, strings.Contains(err.Error(), tc.contains), err.Error())
			}
		})
	}
}
