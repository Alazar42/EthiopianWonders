class_name RouteTypes
extends RefCounted

enum SegmentType {
	STRAIGHT,
	CURVE_LEFT,
	CURVE_RIGHT,
	TURN_LEFT,
	TURN_RIGHT,
	SHARP_LEFT,
	SHARP_RIGHT,
	LANDMARK_APPROACH,
	PLANET_TRANSITION,
	PLANET_ARRIVAL,
	RECOVERY,
}

## Arc length between stored samples of a segment.
const SAMPLE_STEP: float = 1.0

static func is_turn(type: SegmentType) -> bool:
	return type in [
		SegmentType.TURN_LEFT, SegmentType.TURN_RIGHT,
		SegmentType.SHARP_LEFT, SegmentType.SHARP_RIGHT,
	]
