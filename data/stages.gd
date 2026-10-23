extends RefCounted
## Stage list for one run. Each wave is a list of [enemy kind, count]; the next wave
## drops in once most of the current one is destroyed. `time` is "day" (default),
## "sunset" or "night".

const STAGES := [
	{"name": "Satoyama Farmland", "variant": "rural", "waves": [
		[["drone", 4], ["walker", 1]],
		[["drone", 5], ["walker", 2]],
	]},
	{"name": "Suburban Sprawl", "variant": "mixed", "waves": [
		[["drone", 5], ["walker", 2]],
		[["walker", 3], ["drone", 4]],
	]},
	{"name": "Cedar Forest", "variant": "forest", "waves": [
		[["spinner", 1], ["drone", 5]],
		[["walker", 3], ["drone", 5]],
	]},
	{"name": "Neon Arcade", "variant": "downtown", "time": "night", "waves": [
		[["lancer", 2], ["drone", 5]],
		[["walker", 2], ["spinner", 1], ["drone", 4]],
		[["lancer", 2], ["walker", 2]],
	]},
	{"name": "Harbor Strike Group", "variant": "harbor", "elite": true, "waves": [
		[["walker", 3], ["drone", 6]],
		[["spinner", 2], ["lancer", 2]],
	]},
	{"name": "Mountain Pass Woods", "variant": "forest", "waves": [
		[["mortar", 2], ["drone", 7]],
		[["walker", 3], ["mortar", 1], ["drone", 4]],
		[["lancer", 3], ["spinner", 1]],
	]},
	{"name": "Bayshore Route", "variant": "highway", "time": "sunset", "waves": [
		[["spinner", 2], ["drone", 6]],
		[["lancer", 3], ["mortar", 2]],
		[["walker", 4], ["drone", 6]],
	]},
	{"name": "Riverside Wards", "variant": "mixed", "waves": [
		[["walker", 4], ["mortar", 2]],
		[["spinner", 2], ["lancer", 2], ["drone", 6]],
		[["mortar", 3], ["walker", 3]],
	]},
	{"name": "Breach Perimeter", "variant": "rural", "waves": [
		[["spinner", 2], ["walker", 3], ["drone", 6]],
		[["lancer", 4], ["mortar", 2]],
		[["spinner", 3], ["walker", 4], ["drone", 8]],
	]},
	{"name": "The Breach", "variant": "downtown", "time": "sunset", "boss": true, "waves": []},
]
