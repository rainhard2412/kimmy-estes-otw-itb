class_name ColorMatchConfig
extends Resource
## Knobs of the placeholder color-match repair minigame.

## How many correct matches in a row finish the repair.
@export_range(1, 20, 1, "or_greater") var rounds_needed := 3
## How many color buttons to choose from (2 to 6).
@export_range(2, 6, 1) var colors_shown := 4
## 0 = random. Any other number = same rounds every time.
@export var rng_seed := 0


func rounds() -> int:
	return maxi(rounds_needed, 1)

func color_count() -> int:
	return clampi(colors_shown, 2, ColorMatchMinigame.PALETTE.size())
