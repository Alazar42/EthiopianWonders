extends RefCounted
## Procedural low-poly props for the planet generator (offline tool, never used at runtime).
## Every mesh is flat shaded with baked vertex colours. A colour alpha below 1 means "glows":
## assets/shaders/stylized_vertex.gdshader turns (1 - alpha) into emission (lava, acid pools).

class Builder:
	var st := SurfaceTool.new()
	var rng := RandomNumberGenerator.new()

	func _init(seed_value: int = 1) -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		rng.seed = seed_value

	## One flat-shaded triangle facing the side `out` points to.
	## Godot treats clockwise triangles (seen from outside) as front faces.
	func tri(a: Vector3, b: Vector3, c: Vector3, color: Color, out: Vector3) -> void:
		var n0: Vector3 = (b - a).cross(c - a)
		if n0.length_squared() < 0.0000001:
			return
		var normal: Vector3 = n0.normalized()
		if n0.dot(out) >= 0.0:
			var swap: Vector3 = b
			b = c
			c = swap
		else:
			normal = -normal
		for v in [a, b, c]:
			st.set_color(color)
			st.set_normal(normal)
			st.add_vertex(v)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, out: Vector3) -> void:
		tri(a, b, c, color, out)
		tri(a, c, d, color, out)

	## Tapered column; r1 = 0 makes a cone. Pass `top_color` to cap a column.
	func frustum(base: Vector3, r0: float, r1: float, height: float, sides: int,
			side_color: Color, top_color: Color = Color(0, 0, 0, -1), phase: float = 0.0) -> void:
		var slope: float = (r0 - r1) / maxf(height, 0.001)
		for i in sides:
			var a0: float = phase + TAU * float(i) / float(sides)
			var a1: float = phase + TAU * float(i + 1) / float(sides)
			var mid: float = (a0 + a1) * 0.5
			var out := Vector3(cos(mid), slope, sin(mid))
			var p00: Vector3 = base + Vector3(cos(a0) * r0, 0.0, sin(a0) * r0)
			var p01: Vector3 = base + Vector3(cos(a1) * r0, 0.0, sin(a1) * r0)
			var tip := Vector3(0.0, height, 0.0)
			if r1 < 0.0001:
				tri(p00, p01, base + tip, side_color, out)
			else:
				var p10: Vector3 = base + Vector3(cos(a0) * r1, height, sin(a0) * r1)
				var p11: Vector3 = base + Vector3(cos(a1) * r1, height, sin(a1) * r1)
				quad(p00, p01, p11, p10, side_color, out)
				if top_color.a >= 0.0:
					tri(base + tip, p10, p11, top_color, Vector3.UP)

	## Lumpy ellipsoid, shaded from `low` at the bottom to `high` at the top.
	func blob(center: Vector3, radii: Vector3, low: Color, high: Color, detail: int = 1, jitter: float = 0.1) -> void:
		var ico: Array = Builder.icosphere(detail)
		var verts: PackedVector3Array = ico[0]
		var moved := PackedVector3Array()
		for v in verts:
			moved.push_back(v * (1.0 + rng.randf_range(-jitter, jitter)))
		for face in ico[1]:
			var a: Vector3 = center + moved[face[0]] * radii
			var b: Vector3 = center + moved[face[1]] * radii
			var c: Vector3 = center + moved[face[2]] * radii
			var mid: Vector3 = ((verts[face[0]] + verts[face[1]] + verts[face[2]]) / 3.0).normalized()
			var t: float = clampf(mid.y * 0.5 + 0.5, 0.0, 1.0)
			var shade: float = rng.randf_range(0.95, 1.05)
			var col: Color = low.lerp(high, t)
			tri(a, b, c, Color(col.r * shade, col.g * shade, col.b * shade, col.a), mid)

	func box(center: Vector3, size: Vector3, color: Color, basis: Basis = Basis.IDENTITY) -> void:
		var h: Vector3 = size * 0.5
		var c: Array = []
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					c.append(center + basis * Vector3(h.x * sx, h.y * sy, h.z * sz))
		# corner index = x*4 + y*2 + z, each bit 0 = negative side
		quad(c[4], c[5], c[7], c[6], color, basis * Vector3.RIGHT)
		quad(c[0], c[2], c[3], c[1], color, basis * Vector3.LEFT)
		quad(c[2], c[3], c[7], c[6], color, basis * Vector3.UP)
		quad(c[0], c[4], c[5], c[1], color, basis * Vector3.DOWN)
		quad(c[1], c[3], c[7], c[5], color, basis * Vector3.BACK)
		quad(c[0], c[4], c[6], c[2], color, basis * Vector3.FORWARD)

	## Slim four-sided spike from `base` along `dir` (leaves, branches, flower spikes).
	func pyramid(base: Vector3, dir: Vector3, length: float, width: float, color: Color) -> void:
		var d: Vector3 = dir.normalized()
		var side: Vector3 = d.cross(Vector3.UP)
		if side.length_squared() < 0.001:
			side = d.cross(Vector3.RIGHT)
		side = side.normalized()
		var other: Vector3 = side.cross(d).normalized()
		var corners: Array = [
			base + side * width + other * width * 0.35, base - side * width + other * width * 0.35,
			base - side * width - other * width * 0.35, base + side * width - other * width * 0.35,
		]
		var tip: Vector3 = base + d * length
		for i in 4:
			var a: Vector3 = corners[i]
			var b: Vector3 = corners[(i + 1) % 4]
			tri(a, b, tip, color, (a + b) * 0.5 - base)

	static func icosphere(level: int) -> Array:
		var t: float = (1.0 + sqrt(5.0)) / 2.0
		var verts := PackedVector3Array([
			Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
			Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
		])
		for i in verts.size():
			verts[i] = verts[i].normalized()
		var faces: Array = [
			[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
			[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
			[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
			[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
		]
		for _i in level:
			var cache: Dictionary = {}
			var next_faces: Array = []
			for f in faces:
				var ab: int = _midpoint(verts, cache, f[0], f[1])
				var bc: int = _midpoint(verts, cache, f[1], f[2])
				var ca: int = _midpoint(verts, cache, f[2], f[0])
				next_faces.append([f[0], ab, ca])
				next_faces.append([f[1], bc, ab])
				next_faces.append([f[2], ca, bc])
				next_faces.append([ab, bc, ca])
			faces = next_faces
		return [verts, faces]

	static func _midpoint(verts: PackedVector3Array, cache: Dictionary, i: int, j: int) -> int:
		var key: int = mini(i, j) * 100000 + maxi(i, j)
		if cache.has(key):
			return cache[key]
		verts.append(((verts[i] + verts[j]) * 0.5).normalized())
		cache[key] = verts.size() - 1
		return verts.size() - 1

	func commit() -> ArrayMesh:
		return st.commit()

static func icosphere(level: int) -> Array:
	return Builder.icosphere(level)

# --- the props ----------------------------------------------------------------------------------

## Flat-topped acacia, the silhouette of the Rift Valley savanna.
static func acacia() -> ArrayMesh:
	var b := Builder.new(11)
	var bark := Color(0.38, 0.27, 0.18)
	b.frustum(Vector3.ZERO, 0.26, 0.14, 2.1, 6, bark)
	b.pyramid(Vector3(0, 1.7, 0), Vector3(0.7, 0.8, 0.1), 1.5, 0.16, bark)
	b.pyramid(Vector3(0, 1.8, 0), Vector3(-0.6, 0.8, 0.4), 1.5, 0.16, bark)
	b.pyramid(Vector3(0, 1.9, 0), Vector3(0.0, 0.8, -0.7), 1.4, 0.14, bark)
	b.blob(Vector3(0, 3.2, 0), Vector3(2.8, 0.5, 2.8), Color(0.36, 0.48, 0.17), Color(0.52, 0.64, 0.24), 1, 0.08)
	b.blob(Vector3(1.0, 3.45, 0.5), Vector3(1.5, 0.34, 1.5), Color(0.40, 0.52, 0.18), Color(0.56, 0.68, 0.26), 1, 0.08)
	b.blob(Vector3(-1.2, 3.4, -0.5), Vector3(1.3, 0.3, 1.3), Color(0.40, 0.52, 0.18), Color(0.56, 0.68, 0.26), 1, 0.08)
	return b.commit()

## Tall, slim eucalyptus with a sparse blue-green crown, common around Ethiopian highland villages.
static func eucalyptus() -> ArrayMesh:
	var b := Builder.new(12)
	b.frustum(Vector3.ZERO, 0.22, 0.1, 6.2, 6, Color(0.80, 0.74, 0.64))
	b.blob(Vector3(0.1, 4.4, 0), Vector3(0.9, 1.3, 0.9), Color(0.26, 0.46, 0.38), Color(0.38, 0.60, 0.44), 1, 0.12)
	b.blob(Vector3(-0.2, 5.6, 0.1), Vector3(0.8, 1.2, 0.8), Color(0.28, 0.50, 0.40), Color(0.42, 0.64, 0.46), 1, 0.12)
	b.blob(Vector3(0.1, 6.7, -0.1), Vector3(0.6, 1.0, 0.6), Color(0.32, 0.54, 0.42), Color(0.46, 0.68, 0.48), 1, 0.12)
	return b.commit()

## Round mud-walled hut with a conical thatch roof.
static func tukul() -> ArrayMesh:
	var b := Builder.new(13)
	b.frustum(Vector3.ZERO, 1.45, 1.4, 1.45, 10, Color(0.70, 0.50, 0.32))
	b.frustum(Vector3(0, 1.4, 0), 2.1, 1.05, 0.55, 10, Color(0.74, 0.58, 0.26))
	b.frustum(Vector3(0, 1.9, 0), 1.05, 0.04, 1.5, 10, Color(0.84, 0.68, 0.30))
	b.blob(Vector3(0, 3.45, 0), Vector3(0.14, 0.14, 0.14), Color(0.5, 0.38, 0.2), Color(0.6, 0.46, 0.24), 0, 0.0)
	b.box(Vector3(0, 0.5, 1.4), Vector3(0.55, 0.95, 0.12), Color(0.2, 0.14, 0.1))
	return b.commit()

static func _ring(sides: int, radius: float, height: float, jitter: Array) -> Array:
	var ring: Array = []
	for i in sides:
		var a: float = TAU * float(i) / float(sides)
		var r: float = radius * jitter[i]
		ring.append(Vector3(cos(a) * r, height, sin(a) * r))
	return ring

## Stepped rock tower (cliffs, mesas, crags). `heights`/`radii` are unit profiles scaled by
## `size` = (radius, height); `bands` colours each step; the top is a flat cap in `top_color`.
static func tower(b: Builder, base: Vector3, size: Vector2, heights: Array, radii: Array,
		bands: Array, top_color: Color, sides: int = 14, jitter: float = 0.1) -> void:
	var rings: Array = []
	for k in heights.size():
		var offsets: Array = []
		for i in sides:
			offsets.append(rng_range(b.rng, 1.0 - jitter, 1.0 + jitter))
		var ring: Array = []
		for i in sides:
			var a: float = TAU * float(i) / float(sides)
			var r: float = radii[k] * offsets[i] * size.x
			ring.append(base + Vector3(cos(a) * r, heights[k] * size.y, sin(a) * r))
		rings.append(ring)
	for k in heights.size() - 1:
		for i in sides:
			var j: int = (i + 1) % sides
			var mid: Vector3 = (rings[k][i] + rings[k][j]) * 0.5 - base
			var shade: float = rng_range(b.rng, 0.95, 1.05)
			var col: Color = bands[k % bands.size()]
			b.quad(rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i],
				Color(col.r * shade, col.g * shade, col.b * shade), Vector3(mid.x, size.y * 0.1, mid.z))
	var top: Array = rings[heights.size() - 1]
	var top_center: Vector3 = base + Vector3(0, heights[heights.size() - 1] * size.y, 0)
	for i in sides:
		var shade: float = rng_range(b.rng, 0.94, 1.06)
		b.tri(top_center, top[i], top[(i + 1) % sides],
			Color(top_color.r * shade, top_color.g * shade, top_color.b * shade), Vector3.UP)

## Flat-topped Ethiopian mountain (an amba): stepped cliffs, grassy top. Unit radius and height.
static func amba() -> ArrayMesh:
	var b := Builder.new(21)
	var sides: int = 14
	var heights: Array = [0.0, 0.16, 0.34, 0.52, 0.74, 0.92, 1.0]
	var radii: Array = [1.0, 0.96, 0.84, 0.80, 0.70, 0.66, 0.62]
	var bands: Array = [
		Color(0.80, 0.62, 0.42), Color(0.70, 0.54, 0.40), Color(0.84, 0.66, 0.45),
		Color(0.68, 0.52, 0.38), Color(0.78, 0.60, 0.41), Color(0.66, 0.51, 0.38),
	]
	var rings: Array = []
	for k in heights.size():
		var jitter: Array = []
		for i in sides:
			jitter.append(rng_range(b.rng, 0.9, 1.1))
		rings.append(_ring(sides, radii[k], heights[k], jitter))
	for k in heights.size() - 1:
		for i in sides:
			var j: int = (i + 1) % sides
			var mid: Vector3 = (rings[k][i] + rings[k][j]) * 0.5
			var shade: float = rng_range(b.rng, 0.95, 1.05)
			var col: Color = bands[k]
			b.quad(rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i],
				Color(col.r * shade, col.g * shade, col.b * shade), Vector3(mid.x, 0.15, mid.z))
	var top: Array = rings[heights.size() - 1]
	for i in sides:
		var shade: float = rng_range(b.rng, 0.94, 1.06)
		b.tri(Vector3(0, 1.0, 0), top[i], top[(i + 1) % sides], Color(0.42 * shade, 0.60 * shade, 0.27 * shade), Vector3.UP)
	return b.commit()

## Cluster of hexagonal basalt columns (Simien and Danakil).
static func basalt_columns() -> ArrayMesh:
	var b := Builder.new(31)
	var spots: Array = [
		Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 0.87), Vector2(-0.5, 0.87), Vector2(-1, 0),
		Vector2(-0.5, -0.87), Vector2(0.5, -0.87), Vector2(1.5, 0.87), Vector2(-1.5, 0.87), Vector2(0, 1.73),
	]
	for spot in spots:
		var height: float = b.rng.randf_range(1.0, 2.6)
		var shade: float = b.rng.randf_range(0.9, 1.1)
		b.frustum(Vector3(spot.x * 0.76, 0.0, spot.y * 0.76), 0.43, 0.4, height, 6,
			Color(0.26 * shade, 0.26 * shade, 0.30 * shade), Color(0.42 * shade, 0.42 * shade, 0.47 * shade))
	return b.commit()

## Erta Ale style shield volcano with a glowing crater and lava streaks. Unit radius and height.
static func volcano() -> ArrayMesh:
	var b := Builder.new(41)
	var sides: int = 14
	var heights: Array = [0.0, 0.25, 0.5, 0.75, 0.92, 1.0]
	var radii: Array = [1.0, 0.78, 0.56, 0.38, 0.27, 0.22]
	var bands: Array = [
		Color(0.20, 0.17, 0.16), Color(0.26, 0.20, 0.17), Color(0.32, 0.22, 0.17),
		Color(0.38, 0.24, 0.16), Color(0.46, 0.26, 0.14),
	]
	var rings: Array = []
	for k in heights.size():
		var jitter: Array = []
		for i in sides:
			jitter.append(rng_range(b.rng, 0.92, 1.08))
		rings.append(_ring(sides, radii[k], heights[k], jitter))
	for k in heights.size() - 1:
		for i in sides:
			var j: int = (i + 1) % sides
			var mid: Vector3 = (rings[k][i] + rings[k][j]) * 0.5
			var shade: float = rng_range(b.rng, 0.92, 1.08)
			var col: Color = bands[k]
			b.quad(rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i],
				Color(col.r * shade, col.g * shade, col.b * shade), Vector3(mid.x, 0.4, mid.z))
	var rim: Array = rings[heights.size() - 1]
	for i in sides:
		b.tri(Vector3(0, 0.86, 0), rim[i], rim[(i + 1) % sides], Color(1.0, 0.42, 0.08, 0.12), Vector3.UP)
	for start in [1, 5, 10]:
		for k in [4, 3, 2]:
			var j: int = (start + 1) % sides
			var scale := Vector3(1.03, 1.0, 1.03)
			var mid: Vector3 = (rings[k][start] + rings[k][j]) * 0.5
			b.quad(rings[k][start] * scale, rings[k][j] * scale, rings[k - 1][j] * scale, rings[k - 1][start] * scale,
				Color(1.0, 0.45, 0.1, 0.2), Vector3(mid.x, 0.4, mid.z))
	return b.commit()

## Giant lobelia as seen on the Bale moorland: a thick trunk crowned by a spiky green rosette.
static func lobelia() -> ArrayMesh:
	var b := Builder.new(51)
	b.frustum(Vector3.ZERO, 0.26, 0.2, 1.7, 7, Color(0.46, 0.40, 0.30))
	for i in 14:
		var a: float = TAU * float(i) / 14.0
		var shade: float = b.rng.randf_range(0.9, 1.1)
		var tilt: float = 0.25 if i % 2 == 0 else 0.55
		b.pyramid(Vector3(0, 1.65, 0), Vector3(cos(a), tilt, sin(a)), 1.5, 0.13,
			Color(0.30 * shade, 0.52 * shade, 0.26 * shade))
	for i in 5:
		var a: float = TAU * float(i) / 5.0
		b.pyramid(Vector3(0, 1.65, 0), Vector3(cos(a) * 0.9, -0.1, sin(a) * 0.9), 0.9, 0.1, Color(0.62, 0.30, 0.24))
	return b.commit()

## A dead flowering spike of the giant lobelia: tall, dark, wrapped in dried leaves.
static func lobelia_spike() -> ArrayMesh:
	var b := Builder.new(52)
	b.frustum(Vector3.ZERO, 0.22, 0.12, 3.4, 6, Color(0.40, 0.38, 0.34))
	b.frustum(Vector3(0, 3.3, 0), 0.12, 0.0, 1.0, 6, Color(0.32, 0.31, 0.30))
	b.frustum(Vector3(0, 0.6, 0), 0.3, 0.3, 0.5, 6, Color(0.60, 0.58, 0.50))
	return b.commit()

## The player's spaceship, drawn from the Ethiopian fighter concept: a dark charcoal fuselage with a
## glass canopy, swept wings striped green, yellow and red with the blue star roundel, glowing
## wingtip pods and rear engines, and a tail fin in the flag colours. About 3 units wide and 2.9
## long. Local -Z is forward. Colours with alpha below 1 glow (canopy and engines).
static func spaceship() -> ArrayMesh:
	var b := Builder.new(81)
	var charcoal := Color(0.24, 0.25, 0.30)
	var steel := Color(0.40, 0.42, 0.48)
	var light := Color(0.55, 0.57, 0.60)
	var green := Color(0.10, 0.55, 0.22)
	var yellow := Color(0.98, 0.80, 0.12)
	var red := Color(0.86, 0.15, 0.12)
	var engine_glow := Color(0.45, 0.92, 1.0, 0.1)
	# Fuselage: body, raised spine, nose wedge, glass canopy and a belly plate.
	b.box(Vector3(0, 0.02, 0.35), Vector3(0.56, 0.30, 1.5), charcoal)
	b.box(Vector3(0, 0.2, 0.62), Vector3(0.38, 0.14, 0.95), steel)
	b.box(Vector3(0, -0.14, 0.38), Vector3(0.42, 0.12, 1.25), steel)
	b.pyramid(Vector3(0, 0.0, -0.4), Vector3(0, 0, -1), 1.05, 0.28, charcoal)
	b.box(Vector3(0, 0.09, -0.78), Vector3(0.12, 0.02, 0.5), yellow)
	b.blob(Vector3(0, 0.27, -0.12), Vector3(0.2, 0.14, 0.42), Color(0.15, 0.3, 0.45, 0.8), Color(0.45, 0.7, 0.9, 0.7), 1, 0.02)
	for side in [-1.0, 1.0]:
		b.box(Vector3(side * 0.285, 0.05, 0.1), Vector3(0.02, 0.07, 0.46), light)
	# Rear engine block with two glowing nozzles.
	b.box(Vector3(0, 0.03, 0.98), Vector3(0.72, 0.30, 0.45), charcoal)
	for side in [-1.0, 1.0]:
		b.box(Vector3(side * 0.28, 0.03, 1.2), Vector3(0.34, 0.34, 0.36), steel)
		b.box(Vector3(side * 0.28, 0.03, 1.39), Vector3(0.24, 0.24, 0.04), engine_glow)
	# Swept wings, wingtip pods and the star roundel.
	for side in [-1.0, 1.0]:
		_ship_wing(b, side, charcoal, steel, green, yellow, red)
		b.box(Vector3(side * 1.5, -0.03, 0.62), Vector3(0.30, 0.24, 0.84), steel)
		b.box(Vector3(side * 1.5, -0.03, 0.21), Vector3(0.24, 0.07, 0.04), engine_glow)
		b.box(Vector3(side * 1.5, -0.03, 1.05), Vector3(0.22, 0.14, 0.04), engine_glow)
		b.box(Vector3(side * 1.5, 0.1, 0.6), Vector3(0.1, 0.05, 0.5), charcoal)
		var center: Vector3 = _wing_point(side, 0.33, 0.46) + Vector3(0, 0.037, 0)
		b.frustum(center, 0.21, 0.21, 0.012, 14, Color(0.08, 0.18, 0.6), Color(0.08, 0.18, 0.6))
		for k in 2:
			var star_center: Vector3 = center + Vector3(0, 0.02, 0)
			var points := PackedVector3Array()
			for i in 3:
				var angle: float = TAU * float(i) / 3.0 + float(k) * PI / 3.0
				points.append(star_center + Vector3(cos(angle), 0.0, sin(angle)) * 0.16)
			b.tri(points[0], points[1], points[2], yellow, Vector3.UP)
	# Tail fin in the flag colours.
	_ship_fin(b, charcoal, green, yellow, red)
	return b.commit()

## A point on a wing: `s` runs from the root (0) to the tip (1), `f` from the leading edge (0) to the
## trailing edge (1). `side` is -1 for the left wing and 1 for the right.
static func _wing_point(side: float, s: float, f: float) -> Vector3:
	var lead: Vector3 = Vector3(0.24, 0.0, -0.55).lerp(Vector3(1.5, -0.04, 0.38), s)
	var trail: Vector3 = Vector3(0.24, 0.0, 0.98).lerp(Vector3(1.5, -0.04, 0.86), s)
	var p: Vector3 = lead.lerp(trail, f)
	return Vector3(p.x * side, p.y, p.z)

static func _ship_wing(b: Builder, side: float, trim: Color, belly: Color, green: Color, yellow: Color, red: Color) -> void:
	var up := Vector3(0, 0.035, 0)
	var bands: Array = [[0.0, 0.06, trim], [0.06, 0.30, green], [0.30, 0.58, yellow], [0.58, 0.80, red], [0.80, 1.0, trim]]
	for band in bands:
		var f0: float = band[0]
		var f1: float = band[1]
		b.quad(_wing_point(side, 0.0, f0) + up, _wing_point(side, 1.0, f0) + up,
				_wing_point(side, 1.0, f1) + up, _wing_point(side, 0.0, f1) + up, band[2], Vector3.UP)
	b.quad(_wing_point(side, 0.0, 0.0) - up, _wing_point(side, 1.0, 0.0) - up,
			_wing_point(side, 1.0, 1.0) - up, _wing_point(side, 0.0, 1.0) - up, belly, Vector3.DOWN)
	# Leading edge, trailing edge and tip.
	b.quad(_wing_point(side, 0.0, 0.0) + up, _wing_point(side, 1.0, 0.0) + up,
			_wing_point(side, 1.0, 0.0) - up, _wing_point(side, 0.0, 0.0) - up, trim, Vector3(0, 0, -1))
	b.quad(_wing_point(side, 0.0, 1.0) + up, _wing_point(side, 1.0, 1.0) + up,
			_wing_point(side, 1.0, 1.0) - up, _wing_point(side, 0.0, 1.0) - up, trim, Vector3(0, 0, 1))
	b.quad(_wing_point(side, 1.0, 0.0) + up, _wing_point(side, 1.0, 1.0) + up,
			_wing_point(side, 1.0, 1.0) - up, _wing_point(side, 1.0, 0.0) - up, trim, Vector3(side, 0, 0))

static func _ship_fin(b: Builder, trim: Color, green: Color, yellow: Color, red: Color) -> void:
	var root_front := Vector3(0, 0.17, 0.52)
	var root_rear := Vector3(0, 0.17, 1.02)
	var tip_front := Vector3(0, 0.98, 0.98)
	var tip_rear := Vector3(0, 0.98, 1.2)
	var bands: Array = [[0.0, 0.18, trim], [0.18, 0.46, green], [0.46, 0.74, yellow], [0.74, 1.0, red]]
	for side in [-1.0, 1.0]:
		var thick := Vector3(side * 0.02, 0, 0)
		for band in bands:
			var h0: float = band[0]
			var h1: float = band[1]
			var f0: Vector3 = root_front.lerp(tip_front, h0)
			var r0: Vector3 = root_rear.lerp(tip_rear, h0)
			var f1: Vector3 = root_front.lerp(tip_front, h1)
			var r1: Vector3 = root_rear.lerp(tip_rear, h1)
			b.quad(f0 + thick, r0 + thick, r1 + thick, f1 + thick, band[2], Vector3(side, 0, 0))
	# Front and rear edges close the fin.
	b.quad(root_front + Vector3(-0.02, 0, 0), root_front + Vector3(0.02, 0, 0), tip_front + Vector3(0.02, 0, 0), tip_front + Vector3(-0.02, 0, 0), trim, Vector3(0, 0, -1))
	b.quad(root_rear + Vector3(-0.02, 0, 0), root_rear + Vector3(0.02, 0, 0), tip_rear + Vector3(0.02, 0, 0), tip_rear + Vector3(-0.02, 0, 0), trim, Vector3(0, 0, 1))
	b.quad(tip_front + Vector3(-0.02, 0, 0), tip_front + Vector3(0.02, 0, 0), tip_rear + Vector3(0.02, 0, 0), tip_rear + Vector3(-0.02, 0, 0), trim, Vector3.UP)

## Obstacle: a jagged basalt boulder. Dark on purpose, so it stands out against every world.
static func obstacle_boulder() -> ArrayMesh:
	var b := Builder.new(91)
	b.blob(Vector3(0, 0.8, 0), Vector3(1.1, 0.95, 1.0), Color(0.24, 0.23, 0.27), Color(0.46, 0.44, 0.48), 1, 0.2)
	b.blob(Vector3(0.75, 0.35, 0.45), Vector3(0.6, 0.4, 0.55), Color(0.26, 0.25, 0.29), Color(0.42, 0.40, 0.44), 1, 0.2)
	b.blob(Vector3(-0.7, 0.3, -0.5), Vector3(0.5, 0.35, 0.5), Color(0.26, 0.25, 0.29), Color(0.42, 0.40, 0.44), 0, 0.2)
	return b.commit()

## Obstacle: three stones piled together.
static func obstacle_stones() -> ArrayMesh:
	var b := Builder.new(92)
	var low := Color(0.28, 0.26, 0.28)
	var high := Color(0.52, 0.48, 0.46)
	b.blob(Vector3(-0.65, 0.5, 0.15), Vector3(0.72, 0.55, 0.7), low, high, 1, 0.18)
	b.blob(Vector3(0.6, 0.62, -0.1), Vector3(0.82, 0.68, 0.8), low, high, 1, 0.18)
	b.blob(Vector3(0.0, 0.42, 0.8), Vector3(0.62, 0.46, 0.6), low, high, 1, 0.18)
	return b.commit()

## Obstacle: a tall rock spire with a leaning tip.
static func obstacle_spire() -> ArrayMesh:
	var b := Builder.new(93)
	b.frustum(Vector3.ZERO, 0.95, 0.5, 2.0, 6, Color(0.30, 0.30, 0.35), Color(0.46, 0.46, 0.52))
	b.pyramid(Vector3(0, 2.0, 0), Vector3(0.25, 1.0, 0.1), 1.0, 0.36, Color(0.36, 0.36, 0.42))
	b.pyramid(Vector3(0.5, 0.3, 0.3), Vector3(0.6, 1.0, 0.2), 1.3, 0.25, Color(0.32, 0.32, 0.37))
	b.pyramid(Vector3(-0.5, 0.3, -0.2), Vector3(-0.5, 1.0, 0.2), 1.0, 0.22, Color(0.32, 0.32, 0.37))
	return b.commit()

## Silver helichrysum cushion: the grey-green mounds that cover the Afro-alpine plateau.
static func helichrysum() -> ArrayMesh:
	var b := Builder.new(53)
	b.blob(Vector3(0, 0.25, 0), Vector3(0.9, 0.42, 0.9), Color(0.55, 0.60, 0.56), Color(0.80, 0.84, 0.80), 1, 0.12)
	b.blob(Vector3(0.7, 0.18, 0.3), Vector3(0.5, 0.28, 0.5), Color(0.55, 0.60, 0.56), Color(0.78, 0.82, 0.78), 0, 0.1)
	return b.commit()

## Column of steam rising from a crater or hot spring, built from stacked white puffs.
static func steam() -> ArrayMesh:
	var b := Builder.new(54)
	for i in 7:
		var t: float = float(i) / 6.0
		var radius: float = 0.8 + t * 1.5
		b.blob(Vector3(b.rng.randf_range(-0.3, 0.3) * t, t * 7.0, b.rng.randf_range(-0.3, 0.3) * t),
			Vector3(radius, radius * 0.8, radius), Color(0.86, 0.88, 0.92), Color(1.0, 1.0, 1.0), 1, 0.14)
	return b.commit()

## Meskel daisy: the yellow flower that carpets the highlands after the rains.
static func meskel_flower() -> ArrayMesh:
	var b := Builder.new(61)
	var green := Color(0.30, 0.52, 0.22)
	b.frustum(Vector3.ZERO, 0.03, 0.02, 0.5, 3, green)
	for i in 8:
		var a: float = TAU * float(i) / 8.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-dir.z, 0.0, dir.x)
		var inner: Vector3 = Vector3(0, 0.5, 0) + dir * 0.06
		var tip: Vector3 = Vector3(0, 0.52, 0) + dir * 0.3 + Vector3.UP * 0.04
		b.tri(inner - side * 0.06, inner + side * 0.06, tip, Color(1.0, 0.94, 0.30), Vector3.UP)
		b.tri(inner - side * 0.06, inner + side * 0.06, tip, Color(1.0, 0.94, 0.30), Vector3.DOWN)
	b.blob(Vector3(0, 0.52, 0), Vector3(0.09, 0.05, 0.09), Color(0.90, 0.62, 0.10), Color(0.96, 0.72, 0.16), 0, 0.0)
	return b.commit()

## Low-poly cloud puff. `variant` changes the lump layout.
static func cloud(variant: int) -> ArrayMesh:
	var b := Builder.new(70 + variant)
	var count: int = 4 + variant
	for i in count:
		var t: float = float(i) / float(count - 1) - 0.5
		var radius: float = b.rng.randf_range(2.0, 3.4)
		b.blob(Vector3(t * 7.0, b.rng.randf_range(-0.3, 0.6), b.rng.randf_range(-1.0, 1.0)),
			Vector3(radius, radius * 0.62, radius), Color(0.80, 0.85, 0.95), Color(1.0, 1.0, 1.0), 1, 0.1)
	return b.commit()

static func rng_range(rng: RandomNumberGenerator, low: float, high: float) -> float:
	return rng.randf_range(low, high)
