// Package gnordle is the scoring rule of a five-letter guessing game, and
// nothing else.
//
// It imports no chain package, holds no word list and keeps no state: it takes
// a secret and a guess and says how close they are. Which word is today's, who
// may guess, and how often, are the realm's problem.
//
// Live demo: [r/moul/gnordle](/r/moul/gnordle).
package gnordle

import (
	"errors"
	"strings"
)

// Length is the word length. Everything here is written against it.
const Length = 5

// Mark is how one letter of a guess scored.
type Mark byte

const (
	Miss    Mark = 0 // the letter is not in the secret, or not any more
	Present Mark = 1 // in the secret, in another position
	Hit     Mark = 2 // in the secret, in this position
)

func (m Mark) String() string {
	switch m {
	case Hit:
		return "hit"
	case Present:
		return "present"
	}
	return "miss"
}

var (
	ErrLength   = errors.New("gnordle: a guess is five letters")
	ErrAlphabet = errors.New("gnordle: letters a to z only")
)

// Score marks a guess against a secret.
//
// The whole difficulty of this game is repeated letters, and it is settled in
// two passes. Exact positions are taken first and their letters are spent;
// only then does the second pass look for letters elsewhere, drawing from what
// the first pass left. A single pass gets "ALLOY" against "LOYAL" wrong, and
// gets it wrong in a way that looks plausible on most words, which is why it
// survives casual testing.
func Score(secret, guess string) ([Length]Mark, error) {
	var marks [Length]Mark
	if err := Valid(secret); err != nil {
		return marks, err
	}
	if err := Valid(guess); err != nil {
		return marks, err
	}

	var left ['z' - 'a' + 1]int
	for i := 0; i < Length; i++ {
		if secret[i] == guess[i] {
			marks[i] = Hit
			continue
		}
		left[secret[i]-'a']++
	}
	for i := 0; i < Length; i++ {
		if marks[i] == Hit {
			continue
		}
		if n := left[guess[i]-'a']; n > 0 {
			marks[i] = Present
			left[guess[i]-'a'] = n - 1
		}
	}
	return marks, nil
}

// Solved reports whether every letter is a hit.
func Solved(marks [Length]Mark) bool {
	for _, m := range marks {
		if m != Hit {
			return false
		}
	}
	return true
}

// Valid checks a word's shape. Lowercase a-z only: normalising here rather than
// at every call site is what keeps the realm from having to trust its callers.
func Valid(word string) error {
	if len(word) != Length {
		return ErrLength
	}
	for i := 0; i < Length; i++ {
		if word[i] < 'a' || word[i] > 'z' {
			return ErrAlphabet
		}
	}
	return nil
}

// Normalize lowercases a word and trims it, so a caller typing "CRANE " is not
// a different word from "crane".
func Normalize(word string) string { return strings.ToLower(strings.TrimSpace(word)) }

// Encode returns the marks as five digits, 0 miss, 1 present, 2 hit. A whole
// board is six of these, which is small enough to be a URL and stable enough to
// be a contract with a front-end.
func Encode(marks [Length]Mark) string {
	var sb strings.Builder
	for _, m := range marks {
		sb.WriteByte(byte('0' + m))
	}
	return sb.String()
}

// Emoji returns the familiar row of squares: the result of a guess with no
// letter in it, which is what makes a score shareable without spoiling anything.
func Emoji(marks [Length]Mark) string {
	var sb strings.Builder
	for _, m := range marks {
		switch m {
		case Hit:
			sb.WriteString("🟩")
		case Present:
			sb.WriteString("🟨")
		default:
			sb.WriteString("⬛")
		}
	}
	return sb.String()
}

// ErrHardMode is returned when a guess throws away something an earlier guess
// already revealed.
var ErrHardMode = errors.New("gnordle: that guess ignores a letter you already found")

// HardMode checks a guess against everything previous guesses revealed: a
// letter found in place must stay in place, and a letter known to be in the
// word must appear somewhere.
//
// This is the rule a transparent chain is actually good at. It cannot keep the
// answer from you, but it can prove that every guess you made was consistent
// with what you already knew, which is a property no client-side game can
// offer and no player can fake.
//
// The message names what was violated, because "invalid guess" on a game you
// have three guesses left in is worse than no rule at all.
func HardMode(previous []string, secret, guess string) error {
	if err := Valid(guess); err != nil {
		return err
	}
	for _, p := range previous {
		marks, err := Score(secret, p)
		if err != nil {
			return err
		}
		for i := 0; i < Length; i++ {
			switch marks[i] {
			case Hit:
				if guess[i] != p[i] {
					return errors.New("gnordle: position " + itoa(i+1) + " must stay " +
						string(p[i]) + ", you already found it")
				}
			case Present:
				if !strings.ContainsRune(guess, rune(p[i])) {
					return errors.New("gnordle: the word contains " + string(p[i]) +
						", so your guess must too")
				}
			}
		}
	}
	return nil
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	out := ""
	for n > 0 {
		out = string(rune('0'+n%10)) + out
		n /= 10
	}
	return out
}
