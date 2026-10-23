extends RefCounted
## Stage list for one run. Each wave is a list of [enemy kind, count]; the next wave
## drops in once most of the current one is destroyed.

const STAGES := [
	{"name": "Shinjuku Outskirts", "variant": "downtown", "waves": [
		[["drone", 4], ["walker", 1]],
		[["drone", 5], ["walker", 2]],
	]},
	{"name": "Harbor District", "variant": "harbor", "waves": [
		[["drone", 5], ["walker", 2]],
		[["walker", 3], ["drone", 4]],
	]},
	{"name": "Bayshore Route", "variant": "highway", "waves": [
		[["spinner", 1], ["drone", 5]],
		[["walker", 3], ["drone", 5]],
	]},
	{"name": "Neon Arcade", "variant": "downtown", "waves": [
		[["lancer", 2], ["drone", 5]],
		[["walker", 2], ["spinner", 1], ["drone", 4]],
		[["lancer", 2], ["walker", 2]],
	]},
	{"name": "Elite Strike Group", "variant": "harbor", "elite": true, "waves": [
		[["walker", 3], ["drone", 6]],
		[["spinner", 2], ["lancer", 2]],
	]},
	{"name": "Industrial Corridor", "variant": "highway", "waves": [
		[["mortar", 2], ["drone", 7]],
		[["walker", 3], ["mortar", 1], ["drone", 4]],
		[["lancer", 3], ["spinner", 1]],
	]},
	{"name": "Akihabara Grid", "variant": "downtown", "waves": [
		[["spinner", 2], ["drone", 6]],
		[["lancer", 3], ["mortar", 2]],
		[["walker", 4], ["drone", 6]],
	]},
	{"name": "Container Yards", "variant": "harbor", "waves": [
		[["walker", 4], ["mortar", 2]],
		[["spinner", 2], ["lancer", 2], ["drone", 6]],
		[["mortar", 3], ["walker", 3]],
	]},
	{"name": "Breach Perimeter", "variant": "highway", "waves": [
		[["spinner", 2], ["walker", 3], ["drone", 6]],
		[["lancer", 4], ["mortar", 2]],
		[["spinner", 3], ["walker", 4], ["drone", 8]],
	]},
	{"name": "The Breach", "variant": "downtown", "boss": true, "waves": []},
]
