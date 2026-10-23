extends RefCounted
## Power-up catalogue. `max` caps stacks, `weight` is the relative roll chance.
## The effect of each id is applied in game_state.gd `apply_powerup`.

const LIST := [
	{"id": "multishot", "name": "Multishot", "desc": "+1 parallel cannon round per volley.", "color": Color(0.3, 0.9, 1.0), "max": 4, "weight": 1.2},
	{"id": "diagonal", "name": "Fan Array", "desc": "Adds a pair of diagonal shots.", "color": Color(0.4, 0.7, 1.0), "max": 2, "weight": 1.0},
	{"id": "side", "name": "Flank Guns", "desc": "Fire sideways from both shoulders.", "color": Color(0.5, 0.6, 1.0), "max": 1, "weight": 0.7},
	{"id": "rear", "name": "Rear Turret", "desc": "+1 shot fired behind you.", "color": Color(0.6, 0.5, 1.0), "max": 2, "weight": 0.7},
	{"id": "ricochet", "name": "Ricochet", "desc": "Rounds bounce off buildings and arena walls.", "color": Color(0.2, 1.0, 0.8), "max": 3, "weight": 1.0},
	{"id": "pierce", "name": "Piercing Rounds", "desc": "Rounds punch through +1 enemy.", "color": Color(0.9, 0.9, 1.0), "max": 3, "weight": 1.0},
	{"id": "rapid", "name": "Overclock", "desc": "+20% fire rate.", "color": Color(1.0, 0.85, 0.3), "max": 5, "weight": 1.2},
	{"id": "damage", "name": "Heavy Shells", "desc": "+25% damage.", "color": Color(1.0, 0.5, 0.2), "max": 5, "weight": 1.2},
	{"id": "crit", "name": "Targeting AI", "desc": "+10% critical hit chance.", "color": Color(1.0, 0.95, 0.4), "max": 4, "weight": 0.9},
	{"id": "armor", "name": "Reinforced Hull", "desc": "+30 max hull and repair 30.", "color": Color(0.3, 1.0, 0.5), "max": 5, "weight": 1.0},
	{"id": "thrusters", "name": "Jump Jets", "desc": "-25% boost cooldown, +2 move speed.", "color": Color(1.0, 0.6, 0.3), "max": 3, "weight": 0.9},
	{"id": "orbitals", "name": "Guardian Drones", "desc": "+2 orbiting drones that block bullets and ram enemies.", "color": Color(0.4, 1.0, 1.0), "max": 3, "weight": 0.8},
	{"id": "missiles", "name": "Missile Pods", "desc": "+2 homing missiles every salvo.", "color": Color(1.0, 0.4, 0.2), "max": 3, "weight": 0.9},
	{"id": "chain", "name": "Arc Coil", "desc": "Hits may arc lightning to more enemies.", "color": Color(0.6, 0.7, 1.0), "max": 3, "weight": 0.8},
	{"id": "burn", "name": "Plasma Rounds", "desc": "Hits set enemies on fire.", "color": Color(1.0, 0.3, 0.1), "max": 3, "weight": 0.8},
	{"id": "lifesteal", "name": "Salvage Rig", "desc": "Repair 2 hull per kill.", "color": Color(0.5, 1.0, 0.4), "max": 3, "weight": 0.8},
	{"id": "demolisher", "name": "Demolisher", "desc": "x2.5 damage to structures; collapses crush nearby enemies.", "color": Color(1.0, 0.7, 0.4), "max": 2, "weight": 0.8},
	{"id": "rampage", "name": "Rampage", "desc": "Crushing cars and props boosts fire rate.", "color": Color(1.0, 0.3, 0.5), "max": 2, "weight": 0.7},
]


static func find(id: String) -> Dictionary:
	for p in LIST:
		if p.id == id:
			return p
	return {}
