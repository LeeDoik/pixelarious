class_name Persistence
## 프로필 저장/로드 — 웹에서는 user://가 IndexedDB로 영속된다.

static func default_profile() -> Dictionary:
	return {
		"version": 1, "gold": 0,
		"upgrades": {"pick": 1, "lamp": 1, "bag": 1, "boots": 1, "helmet": 1},
		"oil_bottles": 0,
		"journals_found": [], "anomaly_flags": [],
		"relic": {},
		"best_depth": 0, "ending_seen": false, "opening_seen": false,
		"miner_no": 1,
		"settings": {"lang": "ko", "haptics": true, "reduced_flash": false},
	}

static func save_profile(path: String, p: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(p))
		f.close()

static func load_profile(path: String) -> Dictionary:
	var base := default_profile()
	if not FileAccess.file_exists(path):
		return base
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return base
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return base
	return _merge(base, data)

static func _merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in over:
		if out.has(k) and typeof(out[k]) == TYPE_DICTIONARY and typeof(over[k]) == TYPE_DICTIONARY:
			out[k] = _merge(out[k], over[k])
		else:
			var val = over[k]
			# JSON converts all numbers to floats; restore ints where they appear
			if typeof(val) == TYPE_FLOAT and val == int(val):
				out[k] = int(val)
			else:
				out[k] = val
	return out
