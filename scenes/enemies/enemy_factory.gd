extends RefCounted
## Maps enemy kind names used in stage data to their scripts.

const SCRIPTS := {
	"drone": preload("res://scenes/enemies/drone.gd"),
	"walker": preload("res://scenes/enemies/walker.gd"),
	"spinner": preload("res://scenes/enemies/spinner.gd"),
	"lancer": preload("res://scenes/enemies/lancer.gd"),
	"mortar": preload("res://scenes/enemies/mortar.gd"),
	"leviathan": preload("res://scenes/enemies/boss_leviathan.gd"),
}


static func create(kind: String) -> Node:
	return SCRIPTS[kind].new()
