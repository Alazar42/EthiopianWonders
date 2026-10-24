class_name GameState
extends RefCounted

enum State {
	MAIN_MENU,
	STARTING_RUN,
	RUNNING,
	DISCOVERY_FEEDBACK,
	PAUSED,
	GAME_OVER
}

static func state_to_string(state: State) -> String:
	match state:
		State.MAIN_MENU: return "MAIN_MENU"
		State.STARTING_RUN: return "STARTING_RUN"
		State.RUNNING: return "RUNNING"
		State.DISCOVERY_FEEDBACK: return "DISCOVERY_FEEDBACK"
		State.PAUSED: return "PAUSED"
		State.GAME_OVER: return "GAME_OVER"
		_: return "UNKNOWN"
