extends RefCounted
## Low-poly models of Ethiopia's historical and natural landmarks, in the same flat-shaded
## vertex-colour style as the planets. Each is modelled from reference photographs of the real place
## and is a stylised blockout, not a survey. Local +Z is the front (it faces the runner's route).

const PropMeshes = preload("res://tools/prop_meshes.gd")

static func _new(seed_value: int):
	return PropMeshes.Builder.new(seed_value)

## The carved granite-grey stele of Aksum: thirteen storeys of false windows, a false door and a
## rounded top, rising from a stone platform.
static func aksum_stele() -> ArrayMesh:
	var b = _new(101)
	b.box(Vector3(0, 0.2, 0), Vector3(4.4, 0.4, 3.2), Color(0.52, 0.48, 0.43))
	b.box(Vector3(0, 0.55, 0), Vector3(3.2, 0.3, 2.4), Color(0.56, 0.52, 0.47))
	var y: float = 0.7
	var width: float = 2.0
	var depth: float = 1.1
	for i in 13:
		width = 2.0 - 0.05 * float(i)
		depth = 1.1 - 0.022 * float(i)
		var shade: float = 1.0 if i % 2 == 0 else 0.93
		b.box(Vector3(0, y + 0.5, 0), Vector3(width, 1.0, depth), Color(0.58 * shade, 0.63 * shade, 0.59 * shade))
		if i > 0:
			for k in 3:
				b.box(Vector3((float(k) - 1.0) * width * 0.28, y + 0.5, depth * 0.5 + 0.02),
					Vector3(0.3, 0.46, 0.06), Color(0.27, 0.31, 0.29))
		y += 1.0
	b.box(Vector3(0, 1.3, 1.12 * 0.5 + 0.02), Vector3(0.75, 1.1, 0.08), Color(0.30, 0.27, 0.25))
	b.blob(Vector3(0, y + 0.3, 0), Vector3(width * 0.5, 0.9, depth * 0.5), Color(0.54, 0.59, 0.55), Color(0.62, 0.67, 0.63), 1, 0.03)
	return b.commit()

## Fasil Ghebbi: ochre keep with a crenellated top, two domed round towers and a wooden balcony.
static func fasil_castle() -> ArrayMesh:
	var b = _new(102)
	var stone := Color(0.72, 0.64, 0.50)
	var dark := Color(0.34, 0.22, 0.14)
	b.box(Vector3(0, 0.25, 0.4), Vector3(18.0, 0.5, 9.0), Color(0.48, 0.56, 0.30))
	b.box(Vector3(0.5, 3.6, 0), Vector3(6.4, 7.2, 5.2), stone)
	for i in 6:
		b.box(Vector3(-2.4 + float(i) * 1.0 + 0.5, 7.6, 2.4), Vector3(0.6, 0.8, 0.6), stone)
		b.box(Vector3(-2.4 + float(i) * 1.0 + 0.5, 7.6, -2.4), Vector3(0.6, 0.8, 0.6), stone)
	b.box(Vector3(-4.6, 2.4, -0.4), Vector3(3.6, 4.8, 4.4), Color(0.69, 0.61, 0.47))
	for side in [-1.0, 1.0]:
		var x: float = 0.5 + side * 4.0
		b.frustum(Vector3(x, 0.0, 2.9), 1.6, 1.45, 6.0, 10, Color(0.70, 0.62, 0.48))
		b.frustum(Vector3(x, 3.0, 2.9), 1.7, 1.7, 0.22, 10, Color(0.52, 0.46, 0.36))
		b.blob(Vector3(x, 6.0, 2.9), Vector3(1.6, 0.95, 1.6), Color(0.42, 0.42, 0.44), Color(0.56, 0.56, 0.58), 1, 0.04)
		b.box(Vector3(x, 4.4, 4.5), Vector3(0.28, 0.9, 0.1), Color(0.22, 0.16, 0.12))
	b.box(Vector3(0.5, 3.3, 2.9), Vector3(5.4, 0.2, 1.1), dark)
	for k in 5:
		b.box(Vector3(-1.6 + float(k) * 1.0 + 0.5, 3.75, 3.35), Vector3(0.1, 0.55, 0.1), dark)
	for x in [-1.3, 0.5, 2.3]:
		b.box(Vector3(x, 1.5, 2.62), Vector3(0.7, 1.5, 0.1), dark)
		b.box(Vector3(x, 5.0, 2.62), Vector3(0.55, 1.0, 0.1), dark)
	b.box(Vector3(-7.8, 1.4, 0.8), Vector3(5.4, 2.8, 1.2), Color(0.62, 0.55, 0.43))
	b.box(Vector3(8.4, 1.4, 0.8), Vector3(5.4, 2.8, 1.2), Color(0.62, 0.55, 0.43))
	return b.commit()

## Fasilides' Bath: a stone pavilion with corner turrets standing in a rectangular pool.
static func fasilides_bath() -> ArrayMesh:
	var b = _new(103)
	var stone := Color(0.72, 0.66, 0.52)
	b.box(Vector3(0, 0.15, 0), Vector3(12.4, 0.3, 8.2), Color(0.58, 0.52, 0.42))
	b.box(Vector3(0, 0.32, 0), Vector3(11.0, 0.12, 6.8), Color(0.20, 0.52, 0.56))
	for z in [-3.7, 3.7]:
		b.box(Vector3(0, 0.55, z), Vector3(12.2, 0.8, 0.7), stone)
	for x in [-5.8, 5.8]:
		b.box(Vector3(x, 0.55, 0), Vector3(0.7, 0.8, 7.4), stone)
	b.box(Vector3(0, 1.6, 0), Vector3(3.8, 2.6, 3.0), stone)
	b.box(Vector3(0, 3.1, 0), Vector3(3.2, 0.5, 2.5), Color(0.66, 0.60, 0.47))
	for i in 5:
		b.box(Vector3(-1.4 + float(i) * 0.7, 3.55, 1.1), Vector3(0.4, 0.5, 0.4), stone)
	for corner in [Vector2(-1.9, 1.5), Vector2(1.9, 1.5), Vector2(-1.9, -1.5), Vector2(1.9, -1.5)]:
		b.frustum(Vector3(corner.x, 0.3, corner.y), 0.5, 0.42, 3.2, 8, stone)
		b.blob(Vector3(corner.x, 3.5, corner.y), Vector3(0.55, 0.45, 0.55), Color(0.4, 0.4, 0.42), Color(0.55, 0.55, 0.57), 1, 0.05)
	b.box(Vector3(0, 0.6, 3.4), Vector3(1.6, 0.18, 2.4), stone)
	b.box(Vector3(0, 1.2, 1.51), Vector3(0.8, 1.2, 0.08), Color(0.22, 0.16, 0.12))
	return b.commit()

## The great ashlar temple at Yeha: golden dressed-stone courses, one half broken lower than the other.
static func yeha_temple() -> ArrayMesh:
	var b = _new(104)
	var gold := Color(0.80, 0.68, 0.46)
	b.box(Vector3(0, 0.15, 0), Vector3(9.0, 0.3, 6.2), Color(0.66, 0.58, 0.44))
	for i in 17:
		var shade: float = b.rng.randf_range(0.92, 1.06)
		var col := Color(gold.r * shade, gold.g * shade, gold.b * shade)
		var jitter: float = b.rng.randf_range(-0.04, 0.04)
		var y: float = 0.3 + 0.5 * float(i) + 0.25
		if i < 11:
			b.box(Vector3(-2.3 + jitter, y, 0), Vector3(2.6, 0.5, 4.6), col)
		if i < 17:
			b.box(Vector3(2.0 - jitter, y, 0), Vector3(3.2, 0.5, 4.6), col)
		if i < 14:
			b.box(Vector3(0, y, -2.0), Vector3(1.8, 0.5, 0.7), col)
	b.box(Vector3(0, 1.8, 2.31), Vector3(1.6, 3.0, 0.1), Color(0.30, 0.20, 0.12))
	return b.commit()

## Small timber-and-stone church with a red roof and cross finials (Debre Damo, Abuna Yemata).
static func church_small() -> ArrayMesh:
	var b = _new(105)
	b.box(Vector3(0, 0.75, 0), Vector3(3.4, 1.5, 2.4), Color(0.54, 0.42, 0.31))
	b.box(Vector3(0, 1.0, 0), Vector3(3.5, 0.12, 2.5), Color(0.38, 0.28, 0.2))
	b.box(Vector3(0, 1.6, 0), Vector3(3.7, 0.2, 2.7), Color(0.80, 0.28, 0.22))
	b.box(Vector3(0, 1.82, 0), Vector3(2.6, 0.2, 1.7), Color(0.76, 0.26, 0.20))
	for x in [-1.0, 0.0, 1.0]:
		b.frustum(Vector3(x, 1.98, 0), 0.07, 0.03, 0.55, 5, Color(0.86, 0.72, 0.28))
		b.blob(Vector3(x, 2.6, 0), Vector3(0.1, 0.1, 0.1), Color(0.86, 0.72, 0.28), Color(0.95, 0.82, 0.38), 0, 0.0)
	b.box(Vector3(0, 0.6, 1.21), Vector3(0.6, 1.1, 0.08), Color(0.2, 0.14, 0.1))
	for x in [-1.1, 1.1]:
		b.box(Vector3(x, 0.9, 1.21), Vector3(0.3, 0.4, 0.08), Color(0.2, 0.14, 0.1))
	return b.commit()

## Ura Kidane Mehret: round church on a stepped stone base, wicker walls under a red conical roof.
static func ura_kidane() -> ArrayMesh:
	var b = _new(106)
	b.frustum(Vector3.ZERO, 4.7, 4.3, 0.35, 14, Color(0.56, 0.47, 0.37), Color(0.5, 0.42, 0.33))
	b.frustum(Vector3(0, 0.35, 0), 4.3, 3.95, 0.35, 14, Color(0.58, 0.49, 0.38), Color(0.5, 0.42, 0.33))
	b.frustum(Vector3(0, 0.7, 0), 3.5, 3.5, 2.0, 14, Color(0.82, 0.76, 0.60))
	for i in 14:
		var a: float = TAU * float(i) / 14.0
		b.box(Vector3(cos(a) * 3.55, 1.7, sin(a) * 3.55), Vector3(0.16, 2.0, 0.16), Color(0.46, 0.34, 0.22))
	b.frustum(Vector3(0, 2.7, 0), 3.5, 3.6, 0.7, 14, Color(0.30, 0.22, 0.15))
	b.frustum(Vector3(0, 3.4, 0), 4.9, 0.4, 2.7, 14, Color(0.80, 0.27, 0.21))
	b.frustum(Vector3(0, 6.05, 0), 0.14, 0.06, 0.55, 6, Color(0.86, 0.72, 0.28))
	b.blob(Vector3(0, 6.7, 0), Vector3(0.22, 0.22, 0.22), Color(0.86, 0.72, 0.28), Color(0.95, 0.82, 0.38), 0, 0.0)
	b.box(Vector3(0, 6.95, 0), Vector3(0.08, 0.5, 0.08), Color(0.9, 0.78, 0.3))
	b.box(Vector3(0, 7.0, 0), Vector3(0.34, 0.08, 0.08), Color(0.9, 0.78, 0.3))
	b.box(Vector3(0, 1.45, 3.52), Vector3(1.0, 1.5, 0.2), Color(0.16, 0.12, 0.09))
	return b.commit()

## A sandstone pinnacle with a church tucked into its face (Abuna Yemata Guh).
static func abuna_yemata() -> ArrayMesh:
	var b = _new(107)
	var heights: Array = [0.0, 0.2, 0.45, 0.7, 0.9, 1.0]
	var radii: Array = [1.0, 0.86, 0.8, 0.72, 0.66, 0.6]
	var bands: Array = [Color(0.82, 0.62, 0.46), Color(0.76, 0.57, 0.43), Color(0.85, 0.66, 0.49), Color(0.73, 0.55, 0.42), Color(0.80, 0.60, 0.45)]
	PropMeshes.tower(b, Vector3.ZERO, Vector2(4.6, 13.0), heights, radii, bands, Color(0.66, 0.58, 0.34), 12, 0.08)
	PropMeshes.tower(b, Vector3(7.0, 0, -1.0), Vector2(2.8, 8.5), heights, radii, bands, Color(0.66, 0.58, 0.34), 10, 0.08)
	var face_z: float = 3.7
	b.box(Vector3(0, 6.0, face_z), Vector3(2.6, 1.9, 1.0), Color(0.62, 0.44, 0.32))
	b.box(Vector3(0, 7.05, face_z), Vector3(2.9, 0.2, 1.2), Color(0.78, 0.30, 0.24))
	b.box(Vector3(0, 5.8, face_z + 0.52), Vector3(0.7, 1.2, 0.08), Color(0.2, 0.14, 0.1))
	b.box(Vector3(0, 5.0, face_z + 0.4), Vector3(2.2, 0.2, 2.0), Color(0.80, 0.58, 0.42))
	return b.commit()

## Konso: stone-walled terraces with thatched huts, as in the UNESCO cultural landscape.
static func konso_village() -> ArrayMesh:
	var b = _new(108)
	var wall := Color(0.66, 0.60, 0.50)
	var crop := Color(0.50, 0.62, 0.28)
	b.frustum(Vector3.ZERO, 9.4, 8.9, 0.9, 14, wall, crop)
	b.frustum(Vector3(0, 0.9, 0), 7.2, 6.8, 0.9, 14, Color(0.62, 0.56, 0.47), Color(0.62, 0.68, 0.32))
	b.frustum(Vector3(0, 1.8, 0), 5.0, 4.7, 0.9, 14, Color(0.64, 0.58, 0.48), Color(0.58, 0.56, 0.32))
	for spot in [Vector3(-1.9, 2.7, 0.4), Vector3(1.9, 2.7, -0.2), Vector3(0.1, 2.7, 2.1)]:
		b.frustum(spot, 1.15, 1.1, 0.95, 9, Color(0.46, 0.35, 0.23))
		b.frustum(spot + Vector3(0, 0.9, 0), 2.0, 0.06, 2.1, 9, Color(0.74, 0.64, 0.38))
		b.frustum(spot + Vector3(0, 2.9, 0), 0.08, 0.03, 0.5, 4, Color(0.5, 0.4, 0.25))
	for i in 9:
		var a: float = TAU * float(i) / 9.0
		b.blob(Vector3(cos(a) * 6.0, 1.9, sin(a) * 6.0), Vector3(0.8, 0.6, 0.8), Color(0.30, 0.50, 0.24), Color(0.44, 0.62, 0.30), 0, 0.15)
	return b.commit()

## The Blue Nile Falls (Tis Abay): a wide white curtain over a dark lip, with mist and lush banks.
static func blue_nile_falls() -> ArrayMesh:
	var b = _new(109)
	var rock := Color(0.50, 0.46, 0.40)
	var water := Color(0.92, 0.97, 1.0, 0.7)
	b.box(Vector3(0, 6.5, -3.5), Vector3(24.0, 1.4, 6.0), rock)
	b.box(Vector3(-9.5, 3.2, 0), Vector3(7.0, 6.4, 3.0), rock)
	b.box(Vector3(9.5, 3.2, 0), Vector3(7.0, 6.4, 3.0), rock)
	b.box(Vector3(0, 6.9, -9.0), Vector3(22.0, 0.2, 9.0), Color(0.40, 0.70, 0.72))
	for k in 5:
		var x: float = -5.0 + float(k) * 2.5
		var w: float = 2.3 if k % 2 == 0 else 1.9
		b.box(Vector3(x, 3.2, 0.2 + 0.25 * float(k % 2)), Vector3(w, 6.2, 0.7), water)
	b.frustum(Vector3(0, 0, 4.0), 8.0, 8.0, 0.25, 16, Color(0.40, 0.72, 0.74), Color(0.40, 0.72, 0.74))
	for p in [Vector3(-3, 1.0, 3.2), Vector3(0, 1.4, 3.8), Vector3(3.2, 1.0, 3.4), Vector3(0, 2.4, 2.6)]:
		b.blob(p, Vector3(2.6, 1.5, 1.8), Color(0.90, 0.94, 0.98), Color(1.0, 1.0, 1.0), 1, 0.12)
	for p in [Vector3(-13, 6.5, 1), Vector3(13, 6.5, 1), Vector3(-9.5, 6.9, 0.5), Vector3(9.5, 6.9, 0.5), Vector3(-14, 2, 4), Vector3(14, 2, 4)]:
		b.blob(p, Vector3(2.4, 1.9, 2.4), Color(0.16, 0.38, 0.20), Color(0.30, 0.58, 0.28), 1, 0.12)
	return b.commit()

## Harar Jugol: golden stone walls with a pointed-arch gate.
static func harar_gate() -> ArrayMesh:
	var b = _new(110)
	var stone := Color(0.84, 0.68, 0.40)
	b.box(Vector3(0, 0.15, 0), Vector3(16.0, 0.3, 5.0), Color(0.70, 0.60, 0.42))
	for side in [-1.0, 1.0]:
		b.box(Vector3(side * 2.6, 3.0, 0), Vector3(2.0, 6.0, 2.6), stone)
		b.box(Vector3(side * 6.8, 2.0, 0), Vector3(6.4, 4.0, 1.8), Color(0.80, 0.64, 0.38))
		for i in 4:
			b.box(Vector3(side * (4.5 + float(i) * 1.7), 4.4, 0), Vector3(0.9, 0.8, 1.8), stone)
		for k in 7:
			b.box(Vector3(side * (5.0 + float(k % 3) * 1.6), 0.8 + float(k) * 0.55, 0.92), Vector3(1.4, 0.06, 0.05), Color(0.66, 0.5, 0.3))
	var count: int = 9
	for i in count:
		var t: float = float(i) / float(count - 1)
		var angle: float = lerpf(PI, 0.0, t)
		var pos := Vector3(cos(angle) * 1.6, 4.4 + sin(angle) * 1.9, 0.0)
		b.box(pos, Vector3(0.7, 0.9, 2.2), Color(0.78, 0.62, 0.36), Basis(Vector3.BACK, angle - PI * 0.5))
	b.box(Vector3(0, 6.6, 0), Vector3(6.4, 0.8, 2.6), stone)
	b.box(Vector3(0, 2.1, 0), Vector3(2.6, 4.2, 0.4), Color(0.18, 0.12, 0.08))
	return b.commit()

## Tiya: two rows of tall carved stelae, each with a sword-like symbol.
static func tiya_stelae() -> ArrayMesh:
	var b = _new(111)
	b.box(Vector3(0, 0.15, 0), Vector3(16.0, 0.3, 8.0), Color(0.64, 0.60, 0.52))
	for row in 2:
		for i in 6:
			var height: float = 3.2 + float((i * 2 + row) % 4) * 0.7
			var lean: float = (float((i + row) % 3) - 1.0) * 0.05
			var x: float = -6.5 + float(i) * 2.6 + float(row) * 0.8
			var z: float = -1.6 + float(row) * 3.2
			var basis := Basis(Vector3.BACK, lean)
			b.box(Vector3(x, 0.3 + height * 0.5, z), Vector3(1.0, height, 0.4), Color(0.58, 0.54, 0.49), basis)
			b.box(Vector3(x, 0.3 + height * 0.52, z + 0.22), Vector3(0.12, height * 0.5, 0.05), Color(0.34, 0.31, 0.29), basis)
			b.box(Vector3(x, 0.3 + height * 0.36, z + 0.22), Vector3(0.45, 0.1, 0.05), Color(0.34, 0.31, 0.29), basis)
	return b.commit()

## Simien crags: tawny slopes broken by dark basalt towers.
static func simien_crag() -> ArrayMesh:
	var b = _new(112)
	var heights: Array = [0.0, 0.25, 0.5, 0.72, 0.9, 1.0]
	var radii: Array = [1.0, 0.82, 0.7, 0.55, 0.4, 0.3]
	var bands: Array = [Color(0.68, 0.56, 0.42), Color(0.52, 0.48, 0.46), Color(0.46, 0.44, 0.47), Color(0.58, 0.50, 0.42), Color(0.44, 0.43, 0.47)]
	PropMeshes.tower(b, Vector3(0, 0, 0), Vector2(5.2, 15.0), heights, radii, bands, Color(0.54, 0.52, 0.52), 9, 0.14)
	PropMeshes.tower(b, Vector3(-6.0, 0, 1.0), Vector2(3.4, 9.5), heights, radii, bands, Color(0.54, 0.52, 0.52), 8, 0.14)
	PropMeshes.tower(b, Vector3(6.2, 0, -0.5), Vector2(3.0, 7.0), heights, radii, bands, Color(0.54, 0.52, 0.52), 8, 0.14)
	b.blob(Vector3(0, 0.4, 5.0), Vector3(6.0, 0.6, 3.0), Color(0.58, 0.54, 0.30), Color(0.74, 0.70, 0.40), 1, 0.1)
	return b.commit()

## Dallol and the Danakil: a white salt crust, acid-coloured pools, sulfur mounds and ruined huts.
static func danakil_salt() -> ArrayMesh:
	var b = _new(113)
	b.frustum(Vector3.ZERO, 10.0, 9.6, 0.25, 18, Color(0.95, 0.93, 0.84), Color(0.95, 0.93, 0.84))
	var pools: Array = [
		[Vector3(-3.5, 0.0, 1.5), 2.6, Color(0.55, 0.80, 0.15, 0.4)],
		[Vector3(2.2, 0.0, 2.8), 2.2, Color(0.96, 0.52, 0.10, 0.35)],
		[Vector3(0.5, 0.0, -2.6), 2.8, Color(0.98, 0.88, 0.20, 0.4)],
		[Vector3(5.2, 0.0, -1.0), 1.6, Color(0.25, 0.72, 0.55, 0.4)],
	]
	for pool in pools:
		b.frustum(pool[0] + Vector3(0, 0.22, 0), pool[1], pool[1] * 0.96, 0.12, 14, pool[2], pool[2])
	for spot in [Vector3(-6.0, 0.2, -2.0), Vector3(6.2, 0.2, 3.0), Vector3(-1.5, 0.2, 5.2)]:
		b.frustum(spot, 1.5, 0.5, 1.3, 8, Color(0.92, 0.76, 0.20), Color(0.96, 0.84, 0.30))
		b.frustum(spot + Vector3(0, 0.25, 0), 1.35, 0.6, 0.35, 8, Color(0.72, 0.30, 0.16))
	for wall in [
			[Vector3(-3.0, 0.7, -5.5), Vector3(3.2, 1.4, 0.3)], [Vector3(-4.6, 0.6, -4.1), Vector3(0.3, 1.2, 2.6)],
			[Vector3(4.0, 0.5, -5.4), Vector3(2.4, 1.0, 0.3)]]:
		b.box(wall[0] + Vector3(0, 0.2, 0), wall[1], Color(0.92, 0.90, 0.82))
	return b.commit()
