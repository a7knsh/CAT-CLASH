extends Node
## Registry façade over the data scripts plus start-up validation, so a
## broken data entry is reported immediately instead of mid-match.

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	var problems := validate()
	for p in problems:
		push_warning("GameDB: " + p)


func validate() -> Array:
	var out: Array = []
	for id in WeaponDefs.ALL.keys():
		if not SpriteArt.WEAPONS.has(id):
			out.append("weapon '%s' has no sprite" % id)
		var ms := AttackData.moveset(id)
		for k in ["light1", "heavy", "up", "nair", "dair", "uair", "air_heavy", "low"]:
			if not ms.has(k):
				out.append("weapon '%s' missing move %s" % [id, k])
	for id in ArenaDefs.ALL.keys():
		var a: Dictionary = ArenaDefs.ALL[id]
		if a.spawns.size() < 4:
			out.append("arena '%s' needs at least 4 spawns" % id)
	for id in ModeDefs.ALL.keys():
		if not ResourceLoader.exists(ModeDefs.ALL[id].script):
			out.append("mode '%s' script missing" % id)
	for id in CosmeticDefs.ACCESSORIES.keys():
		if not SpriteArt.ACCESSORIES.has(id):
			out.append("accessory '%s' has no sprite" % id)
	return out


func weapon(id: String) -> Dictionary:
	return WeaponDefs.get_def(id)


func arena(id: String) -> Dictionary:
	return ArenaDefs.get_def(id)


func mode(id: String) -> Dictionary:
	return ModeDefs.get_def(id)


func random_arena() -> String:
	return ArenaDefs.ORDER[rng.randi_range(0, ArenaDefs.ORDER.size() - 1)]


func random_roster_skin() -> Dictionary:
	return Sprites.full_skin(CosmeticDefs.ROSTER[rng.randi_range(0, CosmeticDefs.ROSTER.size() - 1)])
