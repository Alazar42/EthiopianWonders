class_name LandmarkCatalog
extends RefCounted

static var _landmarks: Array[LandmarkData] = []

static func get_all_landmarks() -> Array[LandmarkData]:
	if _landmarks.is_empty():
		_initialize_catalog()
	return _landmarks

static func get_landmark_by_id(p_id: String) -> LandmarkData:
	for lm in get_all_landmarks():
		if lm.id == p_id:
			return lm
	return null

static func get_random_undiscovered(fallback_any: bool = true) -> LandmarkData:
	var list = get_all_landmarks()
	var undiscovered: Array[LandmarkData] = []
	for lm in list:
		if not lm.discovered:
			undiscovered.append(lm)
	
	if not undiscovered.is_empty():
		return undiscovered[randi() % undiscovered.size()]
	
	if fallback_any and not list.is_empty():
		return list[randi() % list.size()]
	return null

static func reset_all_discoveries() -> void:
	for lm in get_all_landmarks():
		lm.reset()

static func _initialize_catalog() -> void:
	_landmarks.clear()
	
	# 1. Rock-Hewn Churches of Lalibela
	var lalibela = LandmarkData.new()
	lalibela.id = "lalibela"
	lalibela.name = "Rock-Hewn Churches of Lalibela"
	lalibela.achievement_title = "Monolithic Marvel"
	lalibela.educational_fact = "Chiseled entirely from single masses of red volcanic rock in the 12th-13th centuries, Lalibela features 11 monolithic churches connected by tunnels, recognized as a UNESCO World Heritage site in 1978."
	lalibela.color = Color(0.85, 0.45, 0.35)
	lalibela.graybox_type = "lalibela"
	lalibela.spawn_weight = 1.0
	_landmarks.append(lalibela)

	# 2. Obelisks of Aksum
	var aksum = LandmarkData.new()
	aksum.id = "aksum"
	aksum.name = "Obelisks of Aksum"
	aksum.achievement_title = "Pillar of Antiquity"
	aksum.educational_fact = "Carved from single granite blocks soaring up to 24 meters high, the Aksumite stelae marked subterranean royal tombs and date back to the 4th-century Kingdom of Aksum."
	aksum.color = Color(0.70, 0.72, 0.75)
	aksum.graybox_type = "aksum"
	aksum.spawn_weight = 1.0
	_landmarks.append(aksum)

	# 3. Fasil Ghebbi of Gondar
	var gondar = LandmarkData.new()
	gondar.id = "gondar"
	gondar.name = "Fasil Ghebbi of Gondar"
	gondar.achievement_title = "Camelot of Africa"
	gondar.educational_fact = "Founded by Emperor Fasilides in 1636, this royal fortress-city features castles and palaces blending Portuguese, Moorish, and traditional Aksumite architectural styles."
	gondar.color = Color(0.82, 0.68, 0.45)
	gondar.graybox_type = "gondar"
	gondar.spawn_weight = 1.0
	_landmarks.append(gondar)

	# 4. Simien Mountains
	var simien = LandmarkData.new()
	simien.id = "simien"
	simien.name = "Simien Mountains National Park"
	simien.achievement_title = "Roof of Africa"
	simien.educational_fact = "With dramatic basalt escarpments and peaks reaching 4,550 meters at Ras Dejen, the Simien range is a sanctuary for rare endemic wildlife including the Walia ibex and Gelada baboon."
	simien.color = Color(0.35, 0.60, 0.40)
	simien.graybox_type = "simien"
	simien.spawn_weight = 1.0
	_landmarks.append(simien)

	# 5. Erta Ale & Danakil Depression
	var danakil = LandmarkData.new()
	danakil.id = "danakil"
	danakil.name = "Erta Ale & Danakil Depression"
	danakil.achievement_title = "Gateway to the Abyss"
	danakil.educational_fact = "Lying over 100 meters below sea level in the Afar Triangle, Erta Ale hosts one of Earth's rarest persistent active basaltic lava lakes amidst kaleidoscopic sulfur springs."
	danakil.color = Color(0.95, 0.40, 0.15)
	danakil.graybox_type = "danakil"
	danakil.spawn_weight = 0.9
	_landmarks.append(danakil)

	# 6. Harar Jugol
	var harar = LandmarkData.new()
	harar.id = "harar"
	harar.name = "Harar Jugol (Fortified Historic Town)"
	harar.achievement_title = "City of Peace"
	harar.educational_fact = "Encircled by 16th-century ramparts with five historic gates, Harar is recognized as the fourth-holiest city of Islam, celebrated for its 82 mosques and rich cultural traditions."
	harar.color = Color(0.92, 0.85, 0.50)
	harar.graybox_type = "harar"
	harar.spawn_weight = 0.9
	_landmarks.append(harar)

	# 7. Tiya Megalithic Site
	var tiya = LandmarkData.new()
	tiya.id = "tiya"
	tiya.name = "Tiya Megalithic Site"
	tiya.achievement_title = "Ancient Enigma"
	tiya.educational_fact = "Dating between the 10th and 14th centuries, Tiya is home to 36 engraved megalithic pillars carved with mysterious sword symbols, designated a UNESCO World Heritage site."
	tiya.color = Color(0.60, 0.55, 0.50)
	tiya.graybox_type = "tiya"
	tiya.spawn_weight = 0.8
	_landmarks.append(tiya)

	# 8. Bale Mountains
	var bale = LandmarkData.new()
	bale.id = "bale"
	bale.name = "Bale Mountains National Park"
	bale.achievement_title = "Guardian of the Highlands"
	bale.educational_fact = "Encompassing the high-altitude Sanetti Plateau, Bale Mountains preserves the largest Afro-alpine ecosystem on the continent and the primary refuge of the Ethiopian wolf."
	bale.color = Color(0.30, 0.50, 0.65)
	bale.graybox_type = "bale"
	bale.spawn_weight = 0.8
	_landmarks.append(bale)
