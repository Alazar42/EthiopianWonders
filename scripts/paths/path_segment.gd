class_name PathSegment
extends Node3D

@export var segment_type: PathTypes.SegmentType = PathTypes.SegmentType.STRAIGHT
@export var arc_length: float = 16.0
@export var lane_width: float = 2.2

var start_frame: PathTypes.RouteFrame
var end_frame: PathTypes.RouteFrame
var samples: Array[PathTypes.RouteFrame] = []
var planet: SphericalPlanet = null

# Landmark properties
var landmark_target: LandmarkTarget = null
var landmark_data: LandmarkData = null
var landmark_blockout: Node3D = null
var interaction_deadline_dist: float = 0.0

# Planet transition properties
var is_transition: bool = false
var destination_planet: SphericalPlanet = null

@onready var runway_mesh_instance: MeshInstance3D = $RunwayMeshInstance
@onready var decor_container: Node3D = $Decorations

func _ensure_nodes() -> void:
	if not runway_mesh_instance:
		runway_mesh_instance = get_node_or_null("RunwayMeshInstance")
		if not runway_mesh_instance:
			runway_mesh_instance = MeshInstance3D.new()
			runway_mesh_instance.name = "RunwayMeshInstance"
			add_child(runway_mesh_instance)
	if not decor_container:
		decor_container = get_node_or_null("Decorations")
		if not decor_container:
			decor_container = Node3D.new()
			decor_container.name = "Decorations"
			add_child(decor_container)

func _ready() -> void:
	_ensure_nodes()

## Initialize segment with pre-calculated samples and metadata
func setup_segment(
	p_type: PathTypes.SegmentType,
	p_samples: Array[PathTypes.RouteFrame],
	p_planet: SphericalPlanet
) -> void:
	segment_type = p_type
	samples = p_samples
	planet = p_planet
	
	if not samples.is_empty():
		start_frame = samples[0]
		end_frame = samples[samples.size() - 1]
		arc_length = end_frame.distance - start_frame.distance
	
	_ensure_nodes()
	build_runway_mesh()

## Samples the route frame at a specific cumulative distance
func get_frame_at_distance(dist: float) -> PathTypes.RouteFrame:
	if samples.is_empty():
		return PathTypes.RouteFrame.new()
	if samples.size() == 1 or dist <= samples[0].distance:
		return samples[0]
	if dist >= samples[samples.size() - 1].distance:
		return samples[samples.size() - 1]
	
	# Binary search or linear scan (samples is small, typically 8-16 items)
	for i in range(samples.size() - 1):
		var s0 = samples[i]
		var s1 = samples[i + 1]
		if dist >= s0.distance and dist <= s1.distance:
			var span = s1.distance - s0.distance
			var t = 0.0 if span < 0.0001 else (dist - s0.distance) / span
			
			var pos = s0.position.lerp(s1.position, t)
			if planet and not is_transition:
				pos = planet.get_surface_point(pos)
			
			var up = s0.up.slerp(s1.up, t).normalized()
			var fwd = s0.forward.slerp(s1.forward, t).normalized()
			# Keep fwd orthogonal to up
			fwd = (fwd - up * fwd.dot(up)).normalized()
			
			var rf = PathTypes.RouteFrame.new(pos, fwd, up, dist)
			return rf
	
	return samples[samples.size() - 1]

## Builds the 3D low-poly runway mesh with 3 lanes, borders, and curb rails
func build_runway_mesh() -> void:
	if samples.size() < 2:
		return
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var half_width = lane_width * 1.5 + 0.35
	var curb_width = 0.35
	var track_lift = 0.14
	var curb_lift = 0.28
	
	# Materials / colors: Warm Ethiopian sandstone runway and dark basalt curbs
	var runway_color = Color(0.76, 0.65, 0.48) if not is_transition else Color(0.95, 0.85, 0.35)
	var curb_color = Color(0.38, 0.32, 0.28) if not is_transition else Color(0.90, 0.70, 0.20)
	var divider_color = Color(0.88, 0.82, 0.68)
	
	for i in range(samples.size() - 1):
		var s0 = samples[i]
		var s1 = samples[i + 1]
		
		# Sample 0 cross section
		var c0 = s0.position + s0.up * track_lift
		var r0 = s0.right
		var u0 = s0.up
		
		var p0_left_outer = c0 - r0 * (half_width + curb_width) + u0 * curb_lift
		var p0_left_edge = c0 - r0 * half_width
		var p0_right_edge = c0 + r0 * half_width
		var p0_right_outer = c0 + r0 * (half_width + curb_width) + u0 * curb_lift
		
		# Sample 1 cross section
		var c1 = s1.position + s1.up * track_lift
		var r1 = s1.right
		var u1 = s1.up
		
		var p1_left_outer = c1 - r1 * (half_width + curb_width) + u1 * curb_lift
		var p1_left_edge = c1 - r1 * half_width
		var p1_right_edge = c1 + r1 * half_width
		var p1_right_outer = c1 + r1 * (half_width + curb_width) + u1 * curb_lift
		
		# 1. Main runway surface (quad between left_edge and right_edge)
		_add_quad(st, p0_left_edge, p0_right_edge, p1_right_edge, p1_left_edge, u0, runway_color)
		
		# 2. Left curb
		_add_quad(st, p0_left_outer, p0_left_edge, p1_left_edge, p1_left_outer, u0, curb_color)
		
		# 3. Right curb
		_add_quad(st, p0_right_edge, p0_right_outer, p1_right_outer, p1_right_edge, u0, curb_color)
	
	st.generate_normals()
	var array_mesh = st.commit()
	
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	if is_transition:
		mat.emission_enabled = true
		mat.emission = Color(0.85, 0.70, 0.25)
		mat.emission_energy_multiplier = 0.8
	
	runway_mesh_instance.mesh = array_mesh
	runway_mesh_instance.material_override = mat

func _add_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, normal: Vector3, color: Color) -> void:
	st.set_color(color)
	st.set_normal(normal)
	
	# Triangle 1
	st.add_vertex(v0)
	st.add_vertex(v1)
	st.add_vertex(v2)
	
	# Triangle 2
	st.add_vertex(v0)
	st.add_vertex(v2)
	st.add_vertex(v3)

## Attaches a clickable landmark target and a stylized blockout to this segment
func attach_landmark(target_scene: PackedScene, lm_data: LandmarkData, deadline_dist: float) -> void:
	landmark_data = lm_data
	interaction_deadline_dist = deadline_dist
	
	# Find a frame around 65% of the segment
	var mid_dist = start_frame.distance + arc_length * 0.65
	var mid_frame = get_frame_at_distance(mid_dist)
	
	# 1. Spawn landmark blockout on the side of the road (e.g. 7.5 units to the right)
	landmark_blockout = LandmarkBlockoutBuilder.create_graybox(landmark_data)
	decor_container.add_child(landmark_blockout)
	
	var side_offset = mid_frame.right * 7.5
	var monument_pos = mid_frame.position + side_offset
	if planet:
		monument_pos = planet.get_surface_point(monument_pos)
	
	landmark_blockout.global_position = monument_pos
	# Align monument to local surface normal and facing track
	var mon_up = mid_frame.up
	var mon_fwd = -mid_frame.right # faces toward road
	var mon_right = mon_fwd.cross(mon_up).normalized()
	landmark_blockout.basis = Basis(mon_right, mon_up, -mon_fwd)
	
	# 2. Spawn clickable target elevated near the road / monument
	if target_scene:
		landmark_target = target_scene.instantiate() as LandmarkTarget
		add_child(landmark_target)
		
		# Target position: elevated 3.5 units above ground, 4 units offset to side for prime visibility
		var target_pos = mid_frame.position + mid_frame.right * 4.0 + mid_frame.up * 3.5
		if planet:
			target_pos = planet.get_surface_point(target_pos) + mid_frame.up * 3.5
		landmark_target.global_position = target_pos
		landmark_target.setup(landmark_data, deadline_dist)
