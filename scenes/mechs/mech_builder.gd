extends RefCounted
## Builds mech and kaiju models out of primitive meshes. Each builder returns a
## dictionary of named pivots so scripts can animate legs, torsos and weapons.
## Models face -Z.

const PLAYER_ARMOR := Color(0.22, 0.48, 0.95)
const PLAYER_TRIM := Color(0.95, 0.95, 0.97)
const DARK := Color(0.2, 0.22, 0.28)
const ENEMY_ARMOR := Color(0.32, 0.28, 0.34)


## Enemy hull colours derived from each type's accent, so types read at a glance.
static func enemy_armor(accent: Color) -> StandardMaterial3D:
	return FX.mat(accent.lerp(Color(0.28, 0.27, 0.32), 0.5), 0.5, 0.45, true)


static func enemy_plate(accent: Color) -> StandardMaterial3D:
	return FX.mat(accent.lerp(Color(0.9, 0.88, 0.9), 0.4), 0.3, 0.5, true)


static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _instance(parent, m, pos, mat, rot)


static func cyl(parent: Node3D, r_top: float, r_bottom: float, height: float, pos: Vector3, mat: Material,
		rot := Vector3.ZERO, segments := 10) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return _instance(parent, m, pos, mat, rot)


static func ball(parent: Node3D, radius: float, pos: Vector3, mat: Material, scl := Vector3.ONE, segments := 12) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = maxi(segments / 2, 3)
	var mi := _instance(parent, m, pos, mat, Vector3.ZERO)
	mi.scale = scl
	return mi


static func pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


static func _instance(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


static func _leg(parent: Node3D, x: float, hip_y: float, upper: Material, lower: Material, joint: Material,
		accent: Material, s: float) -> Node3D:
	var hip := pivot(parent, Vector3(x, hip_y, 0))
	var seg := hip_y / 4.0
	box(hip, Vector3(1.6, seg * 1.9, 2.0) * s, Vector3(0, -seg * 0.95, 0), upper)
	box(hip, Vector3(1.9, seg * 0.5, 2.2) * s, Vector3(0, -seg * 2.0, 0), joint)
	box(hip, Vector3(1.8, seg * 1.6, 2.4) * s, Vector3(0, -seg * 2.9, 0.2 * s), lower)
	box(hip, Vector3(2.4, 0.8, 3.6) * s, Vector3(0, -hip_y + 0.4 * s, -0.3 * s), joint)
	box(hip, Vector3(0.3, seg * 0.8, 0.2) * s, Vector3(0, -seg * 2.8, -1.3 * s), accent)
	return hip


# --- player ---------------------------------------------------------------------

static func build_player(root: Node3D) -> Dictionary:
	var armor := FX.mat(PLAYER_ARMOR, 0.6, 0.35, true)
	var trim := FX.mat(PLAYER_TRIM, 0.4, 0.4, true)
	var dark := FX.mat(DARK, 0.5, 0.6, true)
	var cyan := FX.glow(Color(0.3, 0.9, 1.0), 5.0)
	var orange := FX.glow(Color(1.0, 0.55, 0.15), 6.0)

	var model := pivot(root, Vector3.ZERO)
	var legs := pivot(model, Vector3.ZERO)
	var leg_l := _leg(legs, -1.8, 7.0, armor, trim, dark, cyan, 1.0)
	var leg_r := _leg(legs, 1.8, 7.0, armor, trim, dark, cyan, 1.0)
	box(legs, Vector3(4.4, 1.6, 2.6), Vector3(0, 7.3, 0), dark)

	var upper := pivot(model, Vector3(0, 8.2, 0))
	box(upper, Vector3(4.4, 1.4, 3.0), Vector3(0, 0.4, 0), dark)
	box(upper, Vector3(6.0, 3.8, 3.6), Vector3(0, 2.6, 0), armor)
	box(upper, Vector3(4.6, 1.2, 3.8), Vector3(0, 4.0, -0.1), trim)
	cyl(upper, 0.95, 0.95, 0.5, Vector3(0, 2.5, -1.85), orange, Vector3(90, 0, 0), 12)
	box(upper, Vector3(1.9, 1.5, 2.0), Vector3(0, 5.2, -0.2), trim)
	box(upper, Vector3(1.4, 0.3, 0.1), Vector3(0, 5.3, -1.22), cyan)
	box(upper, Vector3(0.25, 1.4, 0.25), Vector3(0.7, 6.4, 0.3), dark)
	box(upper, Vector3(3.8, 3.0, 1.8), Vector3(0, 2.8, 2.6), dark)
	cyl(upper, 0.5, 0.7, 1.2, Vector3(-1.0, 1.0, 3.2), orange, Vector3(-20, 0, 0))
	cyl(upper, 0.5, 0.7, 1.2, Vector3(1.0, 1.0, 3.2), orange, Vector3(-20, 0, 0))

	var arms: Array = []
	for side in [-1.0, 1.0]:
		box(upper, Vector3(2.6, 2.3, 3.2), Vector3(side * 4.1, 3.9, 0), trim)
		box(upper, Vector3(0.2, 0.5, 3.3), Vector3(side * 5.42, 4.2, 0), cyan)
		var arm := pivot(upper, Vector3(side * 4.3, 2.6, 0))
		box(arm, Vector3(1.6, 3.0, 1.8), Vector3(0, -0.9, 0), armor)
		cyl(arm, 0.6, 0.75, 5.2, Vector3(0, -1.6, -2.4), dark, Vector3(90, 0, 0))
		cyl(arm, 0.45, 0.45, 0.3, Vector3(0, -1.6, -5.05), cyan, Vector3(90, 0, 0))
		arms.append(arm)

	return {"model": model, "legs": legs, "leg_l": leg_l, "leg_r": leg_r, "upper": upper,
			"arm_l": arms[0], "arm_r": arms[1]}


# --- enemies ----------------------------------------------------------------------

static func build_drone(root: Node3D, accent: Color) -> Dictionary:
	var armor := enemy_armor(accent)
	var dark := FX.mat(DARK, 0.5, 0.5, true)
	var eye := FX.glow(accent, 6.0)
	var model := pivot(root, Vector3.ZERO)
	var body := pivot(model, Vector3.ZERO)
	ball(body, 1.4, Vector3.ZERO, armor, Vector3(1.0, 0.7, 1.3))
	box(body, Vector3(0.9, 0.5, 0.4), Vector3(0, 0.1, -1.7), eye)
	var rotors: Array = []
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			box(body, Vector3(1.9, 0.3, 0.3), Vector3(x * 1.0, 0.2, z * 1.0), dark, Vector3(0, 45 * x * z, 0))
			var r := pivot(body, Vector3(x * 1.9, 0.4, z * 1.9))
			cyl(r, 1.1, 1.1, 0.12, Vector3.ZERO, FX.glow(accent, 1.5), Vector3.ZERO, 8)
			rotors.append(r)
	cyl(body, 0.15, 0.4, 1.2, Vector3(0, -1.0, 0), eye)
	return {"model": model, "body": body, "rotors": rotors}


static func build_walker(root: Node3D, accent: Color) -> Dictionary:
	var armor := enemy_armor(accent)
	var plate := enemy_plate(accent)
	var dark := FX.mat(DARK, 0.5, 0.6, true)
	var eye := FX.glow(accent, 6.0)
	var model := pivot(root, Vector3.ZERO)
	var leg_l := _leg(model, -1.9, 6.0, armor, plate, dark, eye, 1.1)
	var leg_r := _leg(model, 1.9, 6.0, armor, plate, dark, eye, 1.1)
	var upper := pivot(model, Vector3(0, 6.6, 0))
	box(upper, Vector3(5.8, 3.2, 5.0), Vector3(0, 1.2, 0.3), armor)
	box(upper, Vector3(4.6, 1.0, 4.2), Vector3(0, 3.1, 0.3), plate)
	box(upper, Vector3(3.2, 0.5, 0.2), Vector3(0, 1.8, -2.25), eye)
	for side in [-1.0, 1.0]:
		cyl(upper, 0.5, 0.6, 4.4, Vector3(side * 3.4, 1.0, -2.0), dark, Vector3(90, 0, 0))
		box(upper, Vector3(1.4, 1.8, 2.4), Vector3(side * 3.4, 1.0, 0.2), plate)
		cyl(upper, 0.35, 0.35, 0.3, Vector3(side * 3.4, 1.0, -4.25), eye, Vector3(90, 0, 0))
	box(upper, Vector3(0.2, 2.6, 0.2), Vector3(-1.6, 4.6, 1.6), dark)
	return {"model": model, "leg_l": leg_l, "leg_r": leg_r, "upper": upper}


static func build_spinner(root: Node3D, accent: Color) -> Dictionary:
	var armor := enemy_armor(accent)
	var plate := enemy_plate(accent)
	var dark := FX.mat(DARK, 0.5, 0.6, true)
	var eye := FX.glow(accent, 6.0)
	var model := pivot(root, Vector3.ZERO)
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		var foot := Vector3(cos(a) * 4.2, 0.6, sin(a) * 4.2)
		box(model, Vector3(1.4, 1.2, 1.4), foot, dark)
		box(model, Vector3(0.9, 5.0, 0.9), Vector3(cos(a) * 3.0, 3.0, sin(a) * 3.0), plate,
				Vector3(0, -rad_to_deg(a), 25))
	cyl(model, 3.8, 4.4, 2.6, Vector3(0, 5.6, 0), armor, Vector3.ZERO, 16)
	cyl(model, 4.6, 4.6, 0.4, Vector3(0, 6.9, 0), eye, Vector3.ZERO, 16)
	var ring := pivot(model, Vector3(0, 7.6, 0))
	cyl(ring, 2.6, 3.4, 1.4, Vector3.ZERO, plate, Vector3.ZERO, 12)
	for k in 6:
		var a := TAU * k / 6.0
		box(ring, Vector3(0.8, 0.8, 2.0), Vector3(cos(a) * 3.2, 0, sin(a) * 3.2), dark, Vector3(0, -rad_to_deg(a) + 90, 0))
		ball(ring, 0.45, Vector3(cos(a) * 4.3, 0, sin(a) * 4.3), eye)
	ball(model, 1.6, Vector3(0, 8.8, 0), eye, Vector3(1, 0.6, 1))
	return {"model": model, "ring": ring}


static func build_lancer(root: Node3D, accent: Color) -> Dictionary:
	var armor := enemy_armor(accent)
	var plate := enemy_plate(accent)
	var dark := FX.mat(DARK, 0.5, 0.6, true)
	var eye := FX.glow(accent, 6.0)
	var model := pivot(root, Vector3.ZERO)
	var leg_l := _leg(model, -1.5, 7.0, armor, plate, dark, eye, 0.9)
	var leg_r := _leg(model, 1.5, 7.0, armor, plate, dark, eye, 0.9)
	var upper := pivot(model, Vector3(0, 7.6, 0))
	box(upper, Vector3(4.0, 3.6, 3.0), Vector3(0, 1.8, 0), armor, Vector3(-12, 0, 0))
	box(upper, Vector3(1.4, 1.2, 1.8), Vector3(0, 4.2, -0.6), plate)
	box(upper, Vector3(1.0, 0.25, 0.1), Vector3(0, 4.3, -1.52), eye)
	box(upper, Vector3(1.8, 1.8, 2.4), Vector3(-3.0, 3.0, 0), plate)
	# Lance arm.
	var lance := pivot(upper, Vector3(3.0, 2.0, 0))
	box(lance, Vector3(1.6, 1.6, 2.6), Vector3.ZERO, plate)
	cyl(lance, 0.05, 0.9, 7.5, Vector3(0, 0, -5.0), eye, Vector3(-90, 0, 0))
	# Swept back fins.
	for side in [-1.0, 1.0]:
		box(upper, Vector3(0.3, 4.0, 1.2), Vector3(side * 1.4, 3.6, 2.0), plate, Vector3(-35, 0, side * 15))
	return {"model": model, "leg_l": leg_l, "leg_r": leg_r, "upper": upper, "lance": lance}


static func build_mortar(root: Node3D, accent: Color) -> Dictionary:
	var armor := enemy_armor(accent)
	var plate := enemy_plate(accent)
	var dark := FX.mat(DARK, 0.5, 0.6, true)
	var eye := FX.glow(accent, 6.0)
	var model := pivot(root, Vector3.ZERO)
	for side in [-1.0, 1.0]:
		box(model, Vector3(2.0, 2.6, 7.0), Vector3(side * 3.0, 1.3, 0), dark)
		box(model, Vector3(2.2, 0.6, 7.4), Vector3(side * 3.0, 2.8, 0), plate)
	box(model, Vector3(4.6, 3.0, 5.6), Vector3(0, 4.0, 0), armor)
	box(model, Vector3(2.2, 0.4, 0.2), Vector3(0, 4.6, -2.85), eye)
	var tube := pivot(model, Vector3(0, 6.0, 1.0))
	cyl(tube, 1.3, 1.5, 6.5, Vector3(0, 2.6, 0), plate, Vector3(-30, 0, 0), 12)
	cyl(tube, 1.0, 1.0, 0.3, Vector3(0, 5.4, -1.6), eye, Vector3(-30, 0, 0), 12)
	box(model, Vector3(3.0, 2.0, 1.6), Vector3(0, 4.4, 3.4), plate)
	return {"model": model, "tube": tube}


static func build_leviathan(root: Node3D) -> Dictionary:
	var skin := FX.mat(Color(0.3, 0.48, 0.44), 0.3, 0.45, true)
	var belly := FX.mat(Color(0.7, 0.64, 0.48), 0.1, 0.7, true)
	var horn := FX.mat(Color(0.16, 0.15, 0.2), 0.3, 0.4, true)
	var glow := FX.glow(Color(0.85, 0.2, 1.0), 7.0)
	var model := pivot(root, Vector3.ZERO)
	var body := pivot(model, Vector3.ZERO)
	# Torso and hump.
	ball(body, 1.0, Vector3(0, 17, 2), skin, Vector3(10, 8.5, 13))
	ball(body, 1.0, Vector3(0, 13, -2), belly, Vector3(8, 6, 9))
	# Head.
	var head := pivot(body, Vector3(0, 22, -11))
	ball(head, 1.0, Vector3(0, 0, -2), skin, Vector3(5, 3.6, 6.5))
	box(head, Vector3(6.0, 1.2, 6.0), Vector3(0, -2.6, -4.5), horn)
	box(head, Vector3(5.0, 0.8, 4.2), Vector3(0, -1.8, -5.6), glow)
	for side in [-1.0, 1.0]:
		ball(head, 0.7, Vector3(side * 2.6, 1.0, -6.4), glow)
		cyl(head, 0.1, 1.0, 6.0, Vector3(side * 2.8, 3.4, 0.5), horn, Vector3(-55, 0, side * -20))
	# Dorsal spines that glow.
	for k in 8:
		var z := -6.0 + k * 3.2
		var h := 9.0 - absf(k - 3.0) * 1.2
		cyl(body, 0.1, 1.3, h, Vector3(0, 24.5 + h * 0.25 - k * 0.4, z), glow, Vector3(-25, 0, 0), 6)
	# Glowing veins.
	for side in [-1.0, 1.0]:
		box(body, Vector3(0.5, 10.0, 0.5), Vector3(side * 8.6, 15, 0), glow, Vector3(20, 0, side * 25))
		box(body, Vector3(0.5, 8.0, 0.5), Vector3(side * 7.0, 13, 8), glow, Vector3(-30, 0, side * 20))
	# Arms with claws.
	var arms: Array = []
	for side in [-1.0, 1.0]:
		var arm := pivot(body, Vector3(side * 8.5, 18, -6))
		cyl(arm, 1.8, 2.4, 10.0, Vector3(0, -4.0, -2.0), skin, Vector3(-30, 0, 0))
		for c in 3:
			cyl(arm, 0.05, 0.6, 3.5, Vector3((c - 1) * 1.2, -9.0, -6.0), horn, Vector3(-80, 0, 0), 6)
		ball(arm, 1.0, Vector3(0, -8.4, -4.6), glow, Vector3(0.6, 0.6, 0.6))
		arms.append(arm)
	# Legs.
	var legs: Array = []
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var leg := pivot(model, Vector3(x * 7.0, 13, z * 6.0 + 2.0))
			cyl(leg, 2.6, 3.4, 13.0, Vector3(0, -6.5, 0), skin)
			box(leg, Vector3(6.0, 1.6, 7.0), Vector3(0, -12.6, -0.8), horn)
			legs.append(leg)
	# Tail.
	var tail := pivot(body, Vector3(0, 12, 14))
	var seg_parent: Node3D = tail
	var tail_segments: Array = []
	for k in 6:
		var s := 4.0 - k * 0.55
		var seg := pivot(seg_parent, Vector3(0, -0.6, 4.0 if k > 0 else 0.0))
		ball(seg, 1.0, Vector3(0, 0, 2.0), skin, Vector3(s, s * 0.8, 3.2))
		cyl(seg, 0.05, 0.6, 2.5, Vector3(0, s * 0.8, 2.0), glow, Vector3(-30, 0, 0), 6)
		tail_segments.append(seg)
		seg_parent = seg
	return {"model": model, "body": body, "head": head, "arms": arms, "legs": legs, "tail": tail_segments}
