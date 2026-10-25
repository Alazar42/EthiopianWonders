extends RefCounted
## Low-poly Ethiopian spacecraft that drift between the planets, in the same flat-shaded
## vertex-colour style as everything else (offline tool; see build_content.gd). A colour alpha
## below 1 glows (windows, beacons). The long axis of each craft is local X.
##
## NSS-12 is an imagined orbital station; ETRSS-1 is Ethiopia's first satellite (launched 2019); the
## Selam relay is an imagined communications buoy.

const PropMeshes = preload("res://tools/prop_meshes.gd")

const GREEN := Color(0.0, 0.62, 0.27)
const YELLOW := Color(0.99, 0.84, 0.05)
const RED := Color(0.86, 0.10, 0.14)
const HULL := Color(0.86, 0.88, 0.92)
const HULL_DARK := Color(0.52, 0.55, 0.62)
const PANEL := Color(0.10, 0.18, 0.42)
const PANEL_LINE := Color(0.20, 0.32, 0.62)
const GOLD := Color(0.88, 0.70, 0.22)
const WINDOW := Color(1.0, 0.86, 0.45, 0.35)

static func _new(seed_value: int):
	return PropMeshes.Builder.new(seed_value)

## NSS-12: a spine with a spinning habitat ring, a tricolour-banded hub, two solar wings, a dish and
## a docking arm. About 20 units across.
static func nss12_station() -> ArrayMesh:
	var b = _new(201)
	# Central spine along X (built along Y, then every part is rotated by laying out boxes on X).
	b.box(Vector3(0, 0, 0), Vector3(15.0, 2.2, 2.2), HULL)
	b.box(Vector3(0, 0, 0), Vector3(14.0, 2.4, 2.0), HULL_DARK)
	b.box(Vector3(-7.7, 0, 0), Vector3(1.4, 2.8, 2.8), GOLD)
	b.box(Vector3(7.7, 0, 0), Vector3(1.4, 2.8, 2.8), GOLD)
	# Tricolour band around the middle of the spine.
	b.box(Vector3(-1.2, 0, 0), Vector3(1.2, 2.55, 2.55), GREEN)
	b.box(Vector3(0.0, 0, 0), Vector3(1.2, 2.55, 2.55), YELLOW)
	b.box(Vector3(1.2, 0, 0), Vector3(1.2, 2.55, 2.55), RED)
	# Habitat ring in the YZ plane around the spine, joined by four spokes.
	var segments: int = 18
	var ring_radius: float = 7.0
	for i in segments:
		var angle: float = TAU * float(i) / float(segments)
		var center := Vector3(0, cos(angle) * ring_radius, sin(angle) * ring_radius)
		var basis := Basis(Vector3.RIGHT, angle)
		b.box(center, Vector3(2.4, 1.3, 2.0), HULL, basis)
		if i % 2 == 0:
			b.box(center + basis * Vector3(0, 0.68, 0), Vector3(1.6, 0.1, 1.2), WINDOW, basis)
	for i in 4:
		var angle: float = TAU * float(i) / 4.0 + PI * 0.25
		var basis := Basis(Vector3.RIGHT, angle)
		b.box(basis * Vector3(0, ring_radius * 0.5, 0), Vector3(0.5, ring_radius - 1.4, 0.5), HULL_DARK, basis)
	# Two long solar wings reaching out along Z from booms on the spine.
	for side in [-1.0, 1.0]:
		b.box(Vector3(-5.5, 0, side * 2.2), Vector3(0.5, 0.5, 2.6), HULL_DARK)
		for i in 5:
			var shade: Color = PANEL if i % 2 == 0 else PANEL_LINE
			b.box(Vector3(-5.5, 0, side * (4.1 + float(i) * 2.0)), Vector3(3.6, 0.1, 1.9), shade)
		b.box(Vector3(-5.5, -0.07, side * 9.1), Vector3(3.9, 0.06, 10.4), GOLD)
	# Dish and docking arm.
	b.frustum(Vector3(5.5, 1.1, 0), 0.2, 0.2, 2.4, 6, HULL_DARK)
	b.blob(Vector3(5.5, 3.5, 0), Vector3(1.7, 0.5, 1.7), HULL, HULL, 1, 0.02)
	b.box(Vector3(9.4, 0, 0), Vector3(2.0, 0.6, 0.6), HULL_DARK)
	b.box(Vector3(10.6, 0, 0), Vector3(0.5, 1.4, 1.4), RED)
	# Beacon lights.
	b.blob(Vector3(-8.7, 0, 0), Vector3(0.45, 0.45, 0.45), Color(0.4, 1.0, 0.5, 0.2), Color(0.4, 1.0, 0.5, 0.2), 1, 0.0)
	return b.commit()

## ETRSS-1: a gold-wrapped body with two blue solar wings, a dish and a small antenna.
static func etrss1_satellite() -> ArrayMesh:
	var b = _new(202)
	b.box(Vector3(0, 0, 0), Vector3(3.0, 2.4, 2.4), GOLD)
	b.box(Vector3(0, 1.22, 0), Vector3(3.1, 0.12, 2.5), HULL)
	b.box(Vector3(0, -0.4, 1.22), Vector3(2.9, 0.5, 0.1), GREEN)
	b.box(Vector3(0, 0.1, 1.22), Vector3(2.9, 0.5, 0.1), YELLOW)
	b.box(Vector3(0, 0.6, 1.22), Vector3(2.9, 0.5, 0.1), RED)
	for side in [-1.0, 1.0]:
		b.box(Vector3(0, 0, side * 1.7), Vector3(0.4, 0.4, 1.0), HULL_DARK)
		_wing_z(b, side)
	b.frustum(Vector3(1.9, 0.0, 0), 0.15, 0.15, 1.6, 6, HULL_DARK)
	b.blob(Vector3(1.9, 1.8, 0), Vector3(0.95, 0.35, 0.95), HULL, HULL, 1, 0.02)
	b.pyramid(Vector3(-1.6, 1.2, 0.4), Vector3(-0.3, 1, 0.1), 2.2, 0.05, HULL_DARK)
	b.blob(Vector3(-1.4, 0.4, -1.3), Vector3(0.28, 0.28, 0.28), Color(0.3, 0.9, 1.0, 0.3), Color(0.3, 0.9, 1.0, 0.3), 1, 0.0)
	return b.commit()

static func _wing_z(b, side: float) -> void:
	for i in 4:
		var shade: Color = PANEL if i % 2 == 0 else PANEL_LINE
		b.box(Vector3(0, 0, side * (2.7 + float(i) * 1.5)), Vector3(2.2, 0.08, 1.42), shade)
	b.box(Vector3(0, -0.07, side * 5.2), Vector3(2.4, 0.06, 6.6), GOLD)

## Selam relay: a mast carrying three dishes and a ring of tricolour beacon lamps.
static func selam_relay() -> ArrayMesh:
	var b = _new(203)
	b.frustum(Vector3(0, -4.0, 0), 0.6, 0.35, 8.0, 8, HULL, HULL_DARK)
	b.blob(Vector3(0, -4.2, 0), Vector3(1.4, 0.9, 1.4), HULL_DARK, HULL, 1, 0.03)
	for i in 3:
		var angle: float = TAU * float(i) / 3.0
		var dir := Vector3(cos(angle), 0, sin(angle))
		var base := Vector3(0, 0.6 + float(i) * 1.5, 0) + dir * 0.4
		b.pyramid(base, dir + Vector3(0, 0.25, 0), 2.6, 0.12, HULL_DARK)
		b.blob(base + dir * 2.6 + Vector3(0, 0.6, 0), Vector3(1.3, 1.3, 0.3), HULL, HULL, 1, 0.03)
	var lamps: Array = [GREEN, YELLOW, RED]
	for i in 6:
		var angle: float = TAU * float(i) / 6.0
		var c: Color = lamps[i % 3]
		b.blob(Vector3(cos(angle) * 1.1, 4.2, sin(angle) * 1.1), Vector3(0.28, 0.28, 0.28), Color(c.r, c.g, c.b, 0.15), Color(c.r, c.g, c.b, 0.15), 1, 0.0)
	b.frustum(Vector3(0, 4.0, 0), 0.25, 0.0, 2.6, 6, HULL)
	return b.commit()
