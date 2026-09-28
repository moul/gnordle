package gnordle

import (
	"strings"

	"gno.land/p/nt/svg/v0"
)

const (
	tileW  = 62
	tileGap = 8
	rows   = 6
)

// Colours, fixed rather than inherited: gnoweb serves the SVG inside a data
// URI, which is its own document and inherits nothing from the page, so a
// theme-aware colour would resolve to nothing at all.
const (
	colHit     = "#6aaa64"
	colPresent = "#c9b458"
	colMiss    = "#787c7e"
	colBlank   = "#ffffff"
	colBorder  = "#d3d6da"
	colText    = "#ffffff"
)

// Board draws up to six scored guesses.
//
// reveal decides whether the letters are drawn at all. A finished board shows
// them; a board still in play shows only the colours, which is the difference
// between sharing your result and spoiling somebody else's.
func Board(guesses []string, secret string, reveal bool) string {
	return canvas(guesses, secret, reveal).String()
}

// Image wraps [Board] as a markdown image. The SVG travels inline as a data
// URI, which gnoweb allows for image/svg+xml specifically, so it needs no
// hosting and costs no storage: it is drawn at read time.
func Image(guesses []string, secret string, reveal bool, alt string) string {
	return canvas(guesses, secret, reveal).Render(alt)
}

func canvas(guesses []string, secret string, reveal bool) *svg.Canvas {
	w := Length*tileW + (Length+1)*tileGap
	h := rows*tileW + (rows+1)*tileGap
	c := svg.NewCanvas(w, h).WithViewBox(0, 0, w, h)
	c.AddStyle(".l", "font:700 34px system-ui,sans-serif;text-anchor:middle;text-transform:uppercase")

	for row := 0; row < rows; row++ {
		var marks [Length]Mark
		var word string
		if row < len(guesses) {
			word = guesses[row]
			marks, _ = Score(secret, word)
		}
		for col := 0; col < Length; col++ {
			x := tileGap + col*(tileW+tileGap)
			y := tileGap + row*(tileW+tileGap)
			fill, text := colBlank, colMiss
			if word != "" {
				text = colText
				switch marks[col] {
				case Hit:
					fill = colHit
				case Present:
					fill = colPresent
				default:
					fill = colMiss
				}
			}
			r := svg.NewRectangle(x, y, tileW, tileW, fill)
			if word == "" {
				r.Attr.Stroke = colBorder
				r.Attr.StrokeWidth = "2"
			}
			c.Append(r)
			if word != "" && reveal {
				c.Append(svg.NewText(x+tileW/2, y+tileW/2+12, string(word[col]), text).WithClass("l"))
			}
		}
	}
	return c
}

// Share returns the spoiler-free result: one emoji row per guess.
func Share(guesses []string, secret string) string {
	var sb strings.Builder
	for _, g := range guesses {
		marks, err := Score(secret, g)
		if err != nil {
			continue
		}
		sb.WriteString(Emoji(marks) + "\n")
	}
	return sb.String()
}
