class_name GameState
extends RefCounted

enum State {
	MAIN_MENU,
	STARTING_RUN,
	RUNNING,
	DISCOVERY_FEEDBACK,
	PAUSED,
	GAME_OVER,
}

const TRANSITIONS: Dictionary = {
	State.MAIN_MENU: [State.STARTING_RUN],
	State.STARTING_RUN: [State.RUNNING],
	State.RUNNING: [State.DISCOVERY_FEEDBACK, State.PAUSED, State.GAME_OVER, State.STARTING_RUN],
	State.DISCOVERY_FEEDBACK: [State.RUNNING, State.PAUSED, State.GAME_OVER, State.STARTING_RUN],
	State.PAUSED: [State.RUNNING, State.DISCOVERY_FEEDBACK, State.STARTING_RUN, State.MAIN_MENU],
	State.GAME_OVER: [State.STARTING_RUN, State.MAIN_MENU],
}

static func can_transition(from: State, to: State) -> bool:
	return to in TRANSITIONS[from]

## The world keeps moving while a discovery popup is on screen.
static func is_playing(state: State) -> bool:
	return state == State.RUNNING or state == State.DISCOVERY_FEEDBACK

static func state_name(state: State) -> String:
	return State.keys()[state]
