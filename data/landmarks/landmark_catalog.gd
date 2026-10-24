class_name LandmarkCatalog
extends RefCounted
## Curated, offline landmark records. Facts are deliberately conservative; verify before shipping.

const SCENE_DIR: String = "res://scenes/landmarks/"

static var _landmarks: Array[LandmarkData] = []

static func get_all() -> Array[LandmarkData]:
	if _landmarks.is_empty():
		_build()
	return _landmarks

static func get_by_id(p_id: String) -> LandmarkData:
	for landmark in get_all():
		if landmark.id == p_id:
			return landmark
	return null

static func reset_all_discoveries() -> void:
	for landmark in get_all():
		landmark.reset()

static func _add(p_id: String, p_name: String, p_title: String, p_fact: String, p_weight: float = 1.0) -> void:
	var landmark := LandmarkData.new()
	landmark.id = p_id
	landmark.name = p_name
	landmark.achievement_title = p_title
	landmark.educational_fact = p_fact
	landmark.scene_path = SCENE_DIR + "landmark_%s.tscn" % p_id
	landmark.spawn_weight = p_weight
	_landmarks.append(landmark)

static func _build() -> void:
	_landmarks.clear()
	_add("lalibela", "Rock-Hewn Churches of Lalibela", "Monolithic Marvel",
		"Lalibela's eleven medieval churches were carved down into solid rock. UNESCO inscribed the site in 1978.")
	_add("aksum", "Obelisks of Aksum", "Pillar of Antiquity",
		"The ancient stelae of Aksum were carved from single blocks of stone and mark royal burials. UNESCO inscribed Aksum in 1980.")
	_add("gondar", "Fasil Ghebbi, Gondar", "Camelot of Africa",
		"Emperor Fasilides made Gondar his capital in the 1630s and began its royal enclosure of castles. UNESCO inscribed it in 1979.")
	_add("simien", "Simien Mountains National Park", "Roof of Africa",
		"Deep gorges and basalt escarpments shelter rare animals such as the Walia ibex and the gelada. UNESCO inscribed the park in 1978.")
	_add("danakil", "Erta Ale and the Danakil Depression", "Gateway to the Abyss",
		"The Danakil Depression lies below sea level, and Erta Ale is known for a long-lasting lava lake.", 0.9)
	_add("harar", "Harar Jugol", "City of Walls",
		"Harar's old town is enclosed by a historic wall and holds dozens of mosques. UNESCO inscribed Harar Jugol in 2006.", 0.9)
	_add("tiya", "Tiya Megalithic Site", "Ancient Enigma",
		"Tiya's standing stones, many carved with symbols, mark a medieval burial site. UNESCO inscribed Tiya in 1980.", 0.8)
	_add("bale", "Bale Mountains National Park", "Guardian of the Highlands",
		"The Sanetti Plateau is high Afro-alpine habitat and a stronghold of the Ethiopian wolf.", 0.8)
