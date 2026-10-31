extends RefCounted

const VERSION := 2
var chapter := 0
var node_id := "outer_link"
var flags: Dictionary = {}
var chassis := "graviton"
var seed := "RELAY-EXPEDITION"
var upgrades: Dictionary = {}
var hull := -1.0
var shield := -1.0
var seconds := 0.0
var kills := 0
var damage := 0.0
var attempts: Array[Dictionary] = []
var persist := true
var save_path := "user://campaign_v1.cfg"


func snapshot() -> Dictionary:
	return {"version": VERSION, "chapter": chapter, "node_id": node_id, "flags": flags.duplicate(true), "chassis": chassis, "seed": seed,
		"upgrades": upgrades.duplicate(true), "hull": hull, "shield": shield,
		"seconds": seconds, "kills": kills, "damage": damage, "attempts": attempts.duplicate(true)}


func restore(data: Dictionary, node_count: int) -> bool:
	if int(data.get("version", -1)) != VERSION or not data.get("chassis", "") in ["graviton", "bastion", "scrapper", "redline"]:
		return false
	var index := int(data.get("chapter", -1))
	if index < 0 or index > node_count or not data.get("upgrades", null) is Dictionary:
		return false
	if not data.get("flags", null) is Dictionary or str(data.get("node_id", "")).is_empty():
		return false
	if data["flags"].has("courier_escaped") and not data["flags"]["courier_escaped"] is bool:
		return false
	if data["flags"].has("rescued_carriers") and (not data["flags"]["rescued_carriers"] is int or int(data["flags"]["rescued_carriers"]) < 0 or int(data["flags"]["rescued_carriers"]) > 3):
		return false
	for field in ["spine_sites","records_delivered"]:
		if data["flags"].has(field) and (not data["flags"][field] is int or int(data["flags"][field])<0 or int(data["flags"][field])>(9 if field=="spine_sites" else 3)): return false
	for field in ["power_circuits","stronghold_keys"]:
		if data["flags"].has(field) and (not data["flags"][field] is int or int(data["flags"][field])<0 or int(data["flags"][field])>(3 if field=="power_circuits" else 6)): return false
	if data["flags"].has("convoy_hull") and (not is_finite(float(data["flags"]["convoy_hull"])) or float(data["flags"]["convoy_hull"])<0 or float(data["flags"]["convoy_hull"])>510): return false
	if data["flags"].has("escaped") and not data["flags"]["escaped"] is bool: return false
	for scene in ["listening_room","berth_room","departure_room"]:
		var page_key: String=scene+"_page"
		if data["flags"].has(page_key) and (not data["flags"][page_key] is int or int(data["flags"][page_key])<0 or int(data["flags"][page_key])>2): return false
		var choice_key: String=scene+"_choice"
		var allowed: Array=["spoof","challenge"] if scene=="listening_room" else (["broadcast","silent"] if scene=="berth_room" else ["linked","independent"])
		if data["flags"].has(choice_key) and not data["flags"][choice_key] in allowed: return false
	for key in data["upgrades"]:
		var definition: Dictionary = UpgradeCatalog.get_definition(StringName(key))
		if definition.is_empty() or int(data["upgrades"][key]) < 1 or int(data["upgrades"][key]) > int(definition["max_rank"]):
			return false
	for key in ["hull", "shield", "seconds", "damage"]:
		if not is_finite(float(data.get(key, 0))):
			return false
	var saved_attempts = data.get("attempts",[])
	if not saved_attempts is Array or saved_attempts.size()>256: return false
	for record in saved_attempts:
		if not record is Dictionary or not record.get("won",null) is bool or not record.get("banked",null) is bool: return false
		if record["banked"] and not record["won"]: return false
		if str(record.get("node","")).is_empty() or not is_finite(float(record.get("seconds",-1))) or float(record.get("seconds",-1))<0: return false
	chapter = index
	node_id = str(data["node_id"])
	flags = data["flags"].duplicate(true)
	chassis = data["chassis"]
	seed = str(data.get("seed", "RELAY-EXPEDITION"))
	upgrades = data["upgrades"].duplicate(true)
	hull = maxf(-1, float(data.get("hull", -1)))
	shield = maxf(-1, float(data.get("shield", -1)))
	seconds = maxf(0, float(data.get("seconds", 0)))
	kills = maxi(0, int(data.get("kills", 0)))
	damage = maxf(0, float(data.get("damage", 0)))
	attempts.assign(saved_attempts.duplicate(true))
	return true

func record_attempt(node: String, duration: float, won: bool) -> void:
	attempts.append({"node":node,"seconds":maxf(0,duration),"won":won,"banked":false})
	if attempts.size()>256: attempts.pop_front()


func save_checkpoint() -> Error:
	if not persist:
		return OK
	var config := ConfigFile.new()
	config.set_value("campaign", "checkpoint", snapshot())
	return config.save(save_path)


func load_checkpoint(node_count: int) -> bool:
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return false
	return restore(config.get_value("campaign", "checkpoint", {}), node_count)
