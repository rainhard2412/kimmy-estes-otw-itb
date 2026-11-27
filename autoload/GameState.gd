extends Node
## Global state shared across scenes.

var story_mode := true      # true = HP 0 never means game over (Haikal covers)
var high_score := 0
var unlocked_skills: Array[String] = []
