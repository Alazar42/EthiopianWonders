extends RefCounted
## More low-poly wonders of Ethiopia, in the same flat-shaded vertex-colour style as
## landmark_meshes.gd (offline tool, see build_content.gd). Local +Z is the front.

const PropMeshes = preload("res://tools/prop_meshes.gd")
const GREEN := Color(0.0, 0.62, 0.27)
const YELLOW := Color(0.99, 0.84, 0.05)
const RED := Color(0.86, 0.10, 0.14)

static func _new(seed_value: int):
	return PropMeshes.Builder.new(seed_value)

## Adwa: a stepped stone memorial with a tall tapering column, a gold relief panel and a tricolour
## flag, set against the jagged hills of the battlefield.
static func adwa_monument() -> ArrayMesh:
	var b = _new(121)
	var stone := Color(0.70, 0.64, 0.54)
	b.box(Vector3(0, 0.25, 0), Vector3(13.0, 0.5, 11.0), Color(0.56, 0.50, 0.40))
	b.box(Vector3(0, 0.75, 0), Vector3(10.0, 0.5, 8.4), Color(0.62, 0.56, 0.46))
	b.box(Vector3(0, 1.25, 0), Vector3(7.2, 0.5, 6.0), stone)
	b.frustum(Vector3(0, 1.5, 0), 1.9, 1.05, 11.0, 4, Color(0.78, 0.72, 0.62), Color(0.84, 0.78, 0.68), PI * 0.25)
	b.pyramid(Vector3(0, 12.5, 0), Vector3.UP, 1.8, 0.8, Color(0.84, 0.78, 0.68))
	b.box(Vector3(0, 4.2, 1.2), Vector3(1.9, 3.2, 0.12), Color(0.86, 0.68, 0.22))
	b.box(Vector3(0, 4.2, 1.28), Vector3(1.3, 0.35, 0.06), Color(0.46, 0.34, 0.12))
	b.box(Vector3(0, 5.0, 1.28), Vector3(0.35, 1.2, 0.06), Color(0.46, 0.34, 0.12))
	for side in [-1.0, 1.0]:
		b.box(Vector3(side * 3.3, 3.0, 1.9), Vector3(0.9, 3.0, 0.9), stone)
		b.box(Vector3(side * 3.3, 4.7, 1.9), Vector3(1.2, 0.4, 1.2), Color(0.60, 0.54, 0.44))
	# Flag on a tall mast.
	b.frustum(Vector3(-5.2, 0.5, -1.5), 0.12, 0.08, 9.5, 6, Color(0.70, 0.70, 0.72))
	for i in 3:
		var c: Color = [GREEN, YELLOW, RED][i]
		b.box(Vector3(-4.2, 9.4 - float(i) * 0.5, -1.5), Vector3(2.0, 0.5, 0.06), c)
	# Hills behind.
	for h in [Vector3(-7.0, 0.0, -6.0), Vector3(0.0, 0.0, -8.0), Vector3(7.5, 0.0, -6.5)]:
		b.frustum(h, 3.4, 0.5, 6.0 + absf(h.x) * 0.2, 6, Color(0.60, 0.50, 0.38), Color(0.66, 0.58, 0.44))
	return b.commit()

## Lake Tana: a disc of water with a wooded island, a round monastery church and a papyrus boat.
static func lake_tana() -> ArrayMesh:
	var b = _new(122)
	var water := Color(0.22, 0.52, 0.62)
	b.frustum(Vector3.ZERO, 11.0, 10.6, 0.35, 22, Color(0.58, 0.66, 0.48), water)
	b.frustum(Vector3(0, 0.3, 0), 10.0, 9.8, 0.08, 22, water, Color(0.30, 0.62, 0.70))
	b.blob(Vector3(-1.0, 0.7, -0.5), Vector3(4.2, 1.5, 3.6), Color(0.30, 0.46, 0.22), Color(0.46, 0.64, 0.30), 1, 0.12)
	b.frustum(Vector3(-1.0, 1.9, -0.5), 1.4, 1.3, 1.5, 12, Color(0.78, 0.70, 0.52))
	b.frustum(Vector3(-1.0, 3.4, -0.5), 1.9, 0.08, 1.9, 12, Color(0.62, 0.22, 0.14))
	b.box(Vector3(-1.0, 5.45, -0.5), Vector3(0.1, 0.7, 0.1), Color(0.86, 0.80, 0.50))
	b.box(Vector3(-1.0, 5.55, -0.5), Vector3(0.45, 0.1, 0.1), Color(0.86, 0.80, 0.50))
	for i in 7:
		var a: float = TAU * float(i) / 7.0 + 0.4
		b.blob(Vector3(-1.0 + cos(a) * 3.1, 1.5, -0.5 + sin(a) * 2.6), Vector3(0.85, 0.7, 0.85), Color(0.22, 0.44, 0.20), Color(0.38, 0.60, 0.28), 0, 0.2)
	# A tankwa: the reed boat of the lake, with two paddlers' poles.
	for k in 5:
		var t: float = float(k) / 4.0
		b.box(Vector3(5.0 + (t - 0.5) * 2.4, 0.5 + 0.35 * absf(t - 0.5) * 2.0, 3.6), Vector3(0.7, 0.28, 0.7), Color(0.70, 0.62, 0.34),
			Basis(Vector3.BACK, (t - 0.5) * 0.7))
	b.box(Vector3(5.0, 1.4, 3.6), Vector3(0.08, 1.7, 0.08), Color(0.46, 0.34, 0.20))
	for i in 8:
		var a: float = TAU * float(i) / 8.0
		b.pyramid(Vector3(6.6 + cos(a) * 0.5, 0.35, -3.8 + sin(a) * 0.5), Vector3(cos(a) * 0.2, 1, sin(a) * 0.2), 2.3, 0.1, Color(0.52, 0.64, 0.30))
	return b.commit()

## Sof Omar: a river pouring out of a huge cave mouth under a rock arch hung with stalactites.
static func sof_omar() -> ArrayMesh:
	var b = _new(123)
	var rock := Color(0.58, 0.50, 0.42)
	b.blob(Vector3(0, 3.6, -2.5), Vector3(9.6, 5.0, 5.4), Color(0.44, 0.38, 0.32), Color(0.62, 0.54, 0.44), 1, 0.12)
	b.blob(Vector3(-8.0, 1.8, 0.5), Vector3(3.8, 2.8, 3.4), Color(0.42, 0.37, 0.31), rock, 1, 0.14)
	b.blob(Vector3(8.2, 1.6, 0.8), Vector3(3.4, 2.6, 3.2), Color(0.42, 0.37, 0.31), rock, 1, 0.14)
	# The cave mouth: a dark opening framed by two rock pillars and a lintel.
	b.box(Vector3(0, 2.3, 1.6), Vector3(6.6, 4.4, 2.2), Color(0.06, 0.05, 0.05))
	for side in [-1.0, 1.0]:
		b.blob(Vector3(side * 3.9, 2.4, 2.0), Vector3(1.8, 3.0, 1.9), Color(0.46, 0.40, 0.33), rock, 1, 0.12)
	b.blob(Vector3(0, 4.9, 2.0), Vector3(5.2, 1.3, 1.9), Color(0.50, 0.44, 0.36), Color(0.66, 0.58, 0.47), 1, 0.12)
	for i in 7:
		var x: float = -2.7 + float(i) * 0.9
		b.pyramid(Vector3(x, 4.5, 2.4), Vector3.DOWN, 1.0 + float(i % 3) * 0.45, 0.2, Color(0.70, 0.64, 0.54))
	# The Weyib river runs out of the cave and away toward the viewer.
	b.box(Vector3(0, 0.12, 5.0), Vector3(4.4, 0.18, 7.0), Color(0.24, 0.54, 0.60))
	b.box(Vector3(0.6, 0.14, 9.2), Vector3(3.4, 0.18, 2.2), Color(0.28, 0.60, 0.64))
	for p in [Vector3(-2.6, 0.2, 5.0), Vector3(2.7, 0.2, 6.5), Vector3(-2.2, 0.2, 8.5)]:
		b.blob(p, Vector3(0.7, 0.45, 0.7), Color(0.50, 0.46, 0.40), Color(0.62, 0.58, 0.50), 0, 0.2)
	return b.commit()

## Wenchi: a volcanic crater ring, green slopes dropping to a lake with a monastery island.
static func wenchi_crater() -> ArrayMesh:
	var b = _new(124)
	var count: int = 18
	for i in count:
		var a: float = TAU * float(i) / float(count)
		var r: float = 11.2 + sin(float(i) * 2.3) * 0.7
		b.blob(Vector3(cos(a) * r, 0.9, sin(a) * r), Vector3(2.8, 1.5, 2.8), Color(0.30, 0.48, 0.22), Color(0.48, 0.66, 0.30), 1, 0.12)
	b.frustum(Vector3.ZERO, 12.4, 9.0, 0.5, 22, Color(0.38, 0.54, 0.28), Color(0.34, 0.50, 0.26))
	b.frustum(Vector3(0, 0.4, 0), 9.0, 8.9, 0.12, 22, Color(0.18, 0.46, 0.54), Color(0.26, 0.60, 0.68))
	b.blob(Vector3(1.4, 0.7, -1.0), Vector3(2.6, 1.1, 2.3), Color(0.28, 0.44, 0.22), Color(0.44, 0.60, 0.28), 1, 0.12)
	b.frustum(Vector3(1.4, 1.5, -1.0), 0.85, 0.8, 1.0, 10, Color(0.80, 0.72, 0.54))
	b.frustum(Vector3(1.4, 2.5, -1.0), 1.25, 0.05, 1.3, 10, Color(0.62, 0.22, 0.14))
	for i in 5:
		var a: float = TAU * float(i) / 5.0 + 0.5
		b.blob(Vector3(1.4 + cos(a) * 1.9, 1.4, -1.0 + sin(a) * 1.6), Vector3(0.55, 0.6, 0.55), Color(0.20, 0.40, 0.18), Color(0.34, 0.56, 0.24), 0, 0.2)
	return b.commit()

## Entoto Observatory: a white dome on a round tower, a smaller dome and a dish, with a ground
## station building, standing on a ridge above Addis Ababa.
static func entoto_observatory() -> ArrayMesh:
	var b = _new(125)
	var white := Color(0.92, 0.93, 0.95)
	b.box(Vector3(0, 0.2, 0), Vector3(14.0, 0.4, 10.0), Color(0.54, 0.58, 0.44))
	b.frustum(Vector3(-2.5, 0.4, -0.5), 3.1, 2.9, 3.4, 16, Color(0.80, 0.82, 0.86), Color(0.70, 0.72, 0.76))
	b.blob(Vector3(-2.5, 3.8, -0.5), Vector3(3.1, 2.6, 3.1), white, Color(0.98, 0.98, 1.0), 2, 0.01)
	b.box(Vector3(-2.5, 4.8, 1.6), Vector3(0.9, 2.6, 0.9), Color(0.20, 0.24, 0.32), Basis(Vector3.RIGHT, -0.35))
	b.frustum(Vector3(3.6, 0.4, -2.2), 1.7, 1.6, 2.2, 12, Color(0.80, 0.82, 0.86), Color(0.70, 0.72, 0.76))
	b.blob(Vector3(3.6, 2.6, -2.2), Vector3(1.7, 1.4, 1.7), white, Color(0.98, 0.98, 1.0), 2, 0.01)
	b.box(Vector3(3.6, 3.1, -0.6), Vector3(0.5, 1.4, 0.5), Color(0.20, 0.24, 0.32), Basis(Vector3.RIGHT, -0.35))
	b.box(Vector3(3.2, 1.2, 2.6), Vector3(6.0, 1.6, 2.8), Color(0.84, 0.84, 0.80))
	b.box(Vector3(3.2, 2.1, 2.6), Vector3(6.3, 0.22, 3.1), Color(0.60, 0.22, 0.16))
	for i in 3:
		b.box(Vector3(1.2 + float(i) * 2.0, 1.2, 4.03), Vector3(0.9, 0.8, 0.06), Color(0.24, 0.32, 0.46))
	# A ground-station dish tilted toward the sky.
	b.frustum(Vector3(-5.8, 0.4, 3.4), 0.28, 0.2, 2.0, 6, Color(0.60, 0.62, 0.66))
	b.blob(Vector3(-5.8, 2.6, 3.4), Vector3(1.7, 0.4, 1.7), white, white, 1, 0.02)
	b.pyramid(Vector3(-5.8, 2.7, 3.4), Vector3(0.4, 1, 0), 1.4, 0.06, Color(0.60, 0.62, 0.66))
	# The Ethiopian tricolour on a pole.
	b.frustum(Vector3(5.8, 0.4, 3.4), 0.08, 0.06, 5.0, 6, Color(0.74, 0.74, 0.76))
	for i in 3:
		b.box(Vector3(6.5, 5.1 - float(i) * 0.4, 3.4), Vector3(1.4, 0.4, 0.05), [GREEN, YELLOW, RED][i])
	return b.commit()

## Hadar and Lucy: banded badlands of the Afar, a small shelter, and a display with the bone-white
## skeleton of the 3.2-million-year-old Australopithecus afarensis found there in 1974.
static func lucy_hadar() -> ArrayMesh:
	var b = _new(126)
	var strata: Array = [Color(0.72, 0.50, 0.34), Color(0.84, 0.70, 0.50), Color(0.66, 0.46, 0.34), Color(0.88, 0.78, 0.60), Color(0.60, 0.42, 0.32)]
	for mesa in [[Vector3(-4.5, 0, -3.0), Vector2(5.6, 4.6)], [Vector3(3.5, 0, -4.2), Vector2(4.4, 3.8)], [Vector3(8.5, 0, -1.0), Vector2(3.2, 2.8)]]:
		var origin: Vector3 = mesa[0]
		var size: Vector2 = mesa[1]
		for i in strata.size():
			var shrink: float = 1.0 - 0.07 * float(i)
			b.box(origin + Vector3(0, 0.55 + float(i) * 1.0, 0), Vector3(size.x * shrink, 1.0, size.y * shrink), strata[i])
	b.box(Vector3(0, 0.12, 2.4), Vector3(15.0, 0.24, 8.0), Color(0.80, 0.66, 0.46))
	# Display plinth with the skeleton, enlarged so it reads from a distance.
	b.box(Vector3(0, 0.55, 3.4), Vector3(4.6, 0.7, 2.6), Color(0.46, 0.40, 0.34))
	var bone := Color(0.96, 0.93, 0.84)
	b.blob(Vector3(-1.5, 1.55, 3.4), Vector3(0.38, 0.36, 0.34), bone, bone, 1, 0.05)
	b.box(Vector3(-0.2, 1.45, 3.4), Vector3(2.4, 0.16, 0.26), bone)
	for i in 6:
		var x: float = -0.9 + float(i) * 0.38
		b.box(Vector3(x, 1.75, 3.4), Vector3(0.1, 0.5, 0.7 - 0.05 * float(i)), bone, Basis(Vector3.RIGHT, 0.0))
	b.box(Vector3(1.4, 1.35, 3.0), Vector3(0.18, 0.18, 0.9), bone)
	b.box(Vector3(1.4, 1.35, 3.8), Vector3(0.18, 0.18, 0.9), bone)
	b.box(Vector3(1.7, 1.2, 3.4), Vector3(0.9, 0.2, 0.2), bone)
	# A field tent and a few stakes.
	b.pyramid(Vector3(-5.4, 0.25, 4.6), Vector3.UP, 2.4, 1.6, Color(0.88, 0.84, 0.72))
	b.box(Vector3(-5.4, 0.9, 5.4), Vector3(0.9, 1.3, 0.1), Color(0.30, 0.26, 0.22))
	for k in 4:
		b.box(Vector3(4.6 + float(k) * 0.7, 0.6, 5.0), Vector3(0.08, 0.8, 0.08), Color(0.46, 0.34, 0.22))
	return b.commit()

## Dorze: tall woven beehive houses of the Gamo highlands, with enset plants and a bamboo fence.
static func dorze_huts() -> ArrayMesh:
	var b = _new(127)
	b.frustum(Vector3.ZERO, 11.0, 10.6, 0.3, 18, Color(0.52, 0.62, 0.32), Color(0.50, 0.62, 0.30))
	var huts: Array = [[Vector3(-2.0, 0.3, -0.5), 1.0], [Vector3(3.8, 0.3, 1.8), 0.72], [Vector3(-5.6, 0.3, 2.8), 0.6]]
	for hut in huts:
		var base: Vector3 = hut[0]
		var s: float = hut[1]
		var weave := Color(0.78, 0.64, 0.38)
		var band := Color(0.60, 0.46, 0.26)
		b.frustum(base, 2.3 * s, 2.6 * s, 2.6 * s, 14, weave)
		b.frustum(base + Vector3(0, 2.6 * s, 0), 2.6 * s, 1.5 * s, 3.2 * s, 14, band)
		b.frustum(base + Vector3(0, 5.8 * s, 0), 1.5 * s, 0.35 * s, 2.8 * s, 14, weave)
		b.frustum(base + Vector3(0, 8.5 * s, 0), 0.35 * s, 0.05 * s, 1.6 * s, 8, band)
		for ring in 5:
			b.frustum(base + Vector3(0, (0.8 + float(ring) * 1.6) * s, 0), (2.62 - 0.22 * float(ring)) * s, (2.5 - 0.22 * float(ring)) * s, 0.14 * s, 14, band)
		b.box(base + Vector3(0, 1.1 * s, 2.45 * s), Vector3(1.0 * s, 1.9 * s, 0.14 * s), Color(0.20, 0.14, 0.10))
	for i in 9:
		var a: float = lerpf(-0.6, 3.7, float(i) / 8.0)
		b.box(Vector3(cos(a) * 7.8, 0.85, sin(a) * 7.8 + 1.0), Vector3(0.12, 1.4, 0.12), Color(0.66, 0.52, 0.30))
	for k in 3:
		var origin := Vector3(6.4 - float(k) * 1.4, 0.3, -3.6 + float(k) * 1.1)
		for leaf in 7:
			var a: float = TAU * float(leaf) / 7.0
			b.pyramid(origin, Vector3(cos(a) * 0.7, 1.0, sin(a) * 0.7), 2.4, 0.3, Color(0.28, 0.52, 0.22))
	return b.commit()
