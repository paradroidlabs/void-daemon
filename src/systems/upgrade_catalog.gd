class_name UpgradeCatalog
extends RefCounted

## Dependency-free upgrade data and deterministic offer generation.
##
## Upgrade state is a Dictionary keyed by upgrade id. Values may be integer ranks
## or Dictionaries containing a `rank` field. Example:
##     {"FORK_ON_KILL": 2, "SHIELD_CAPACITOR": {"rank": 1}}

const OFFER_SIZE: int = 3
const CATALOG_VERSION: int = 1

const _U32_MASK: int = 0xffffffff
const _FNV_OFFSET_BASIS: int = 2166136261
const _FNV_PRIME: int = 16777619
const _NON_ZERO_RNG_SEED: int = 0x6d2b79f5

const _DEFINITIONS: Array[Dictionary] = [
	{
		"id": "FORK_ON_KILL",
		"title": "FORK_ON_KILL",
		"description": "A MASS_DRIVER killing hit forks toward another target. Each rank adds one fork; child rounds cannot fork again.",
		"max_rank": 3,
		"category": "patch",
		"target": "MASS_DRIVER",
		"tags": ["KINETIC", "ON_KILL", "GEOMETRY"],
		"effect": {
			"forks_per_rank": 1,
			"child_damage_scale": 0.45,
			"child_can_trigger_parent": false,
		},
	},
	{
		"id": "RETURN_VECTOR",
		"title": "RETURN_VECTOR",
		"description": "MASS_DRIVER rounds reverse once at the edge of their range and cross the ship on the return path.",
		"max_rank": 2,
		"category": "patch",
		"target": "MASS_DRIVER",
		"tags": ["KINETIC", "RETURN", "GEOMETRY"],
		"effect": {
			"return_enabled": true,
			"return_damage_scale_base": 0.55,
			"return_damage_scale_per_rank": 0.15,
		},
	},
	{
		"id": "DRIVER_RAIL",
		"title": "DRIVER_RAIL",
		"description": "MASS_DRIVER gains one additional penetration per rank, but each shot travels through a narrower targeting cone.",
		"max_rank": 3,
		"category": "patch",
		"target": "MASS_DRIVER",
		"tags": ["KINETIC", "PIERCE", "TARGETING"],
		"effect": {
			"pierce_per_rank": 1,
			"target_cone_scale_per_rank": -0.08,
		},
	},
	{
		"id": "CONDUCTIVE_MARK",
		"title": "CONDUCTIVE_MARK",
		"description": "ARC.EXE marks its final contact. The next discharge may begin from that contact and gains one extra jump per rank.",
		"max_rank": 3,
		"category": "patch",
		"target": "ARC.EXE",
		"tags": ["ARC", "MARK", "CHAIN"],
		"effect": {
			"mark_duration": 2.5,
			"extra_jumps_per_rank": 1,
		},
	},
	{
		"id": "ARC_FANOUT",
		"title": "ARC_FANOUT",
		"description": "ARC.EXE branches from its first contact to an additional nearby target per rank, while producing more heat.",
		"max_rank": 2,
		"category": "patch",
		"target": "ARC.EXE",
		"tags": ["ARC", "FORK", "GEOMETRY", "HEAT"],
		"effect": {
			"initial_branches_per_rank": 1,
			"heat_multiplier_per_rank": 0.12,
		},
	},
	{
		"id": "GROUND_LOOP",
		"title": "GROUND_LOOP",
		"description": "The last ARC.EXE jump returns energy to the ship, reducing VENT cooldown when a full chain completes.",
		"max_rank": 3,
		"category": "patch",
		"target": "ARC.EXE",
		"tags": ["ARC", "CHAIN", "VENT"],
		"effect": {
			"vent_cooldown_refund_per_rank": 0.18,
			"requires_full_chain": true,
		},
	},
	{
		"id": "HULL_PLATING",
		"title": "HULL_PLATING",
		"description": "Install sacrificial hull plating. Maximum hull increases and the new capacity is repaired immediately.",
		"max_rank": 3,
		"category": "system",
		"target": "HULL",
		"tags": ["HULL", "SURVIVAL"],
		"effect": {
			"max_hull_per_rank": 18.0,
			"repair_on_install": true,
		},
	},
	{
		"id": "KINETIC_DAMPERS",
		"title": "KINETIC_DAMPERS",
		"description": "After taking hull damage, extend collision grace and briefly increase thrust away from nearby contacts.",
		"max_rank": 2,
		"category": "system",
		"target": "HULL",
		"tags": ["HULL", "MOVEMENT", "ON_HIT"],
		"effect": {
			"collision_grace_per_rank": 0.12,
			"escape_thrust_duration": 0.35,
		},
	},
	{
		"id": "SHIELD_CAPACITOR",
		"title": "SHIELD_CAPACITOR",
		"description": "Increase maximum shield. Installing the capacitor also fills the added capacity.",
		"max_rank": 3,
		"category": "system",
		"target": "SHIELD",
		"tags": ["SHIELD", "SURVIVAL"],
		"effect": {
			"max_shield_per_rank": 12.0,
			"restore_on_install": true,
		},
	},
	{
		"id": "SHIELD_REBOOT",
		"title": "SHIELD_REBOOT",
		"description": "Shield regeneration restarts sooner after damage and begins with a short burst of recovery.",
		"max_rank": 3,
		"category": "system",
		"target": "SHIELD",
		"tags": ["SHIELD", "RECOVERY"],
		"effect": {
			"regen_delay_reduction_per_rank": 0.35,
			"reboot_burst_per_rank": 3.0,
		},
	},
	{
		"id": "VENT_AMPLIFIER",
		"title": "VENT_AMPLIFIER",
		"description": "VENT reaches farther and applies more force. Its pulse strength continues to scale with heat dumped.",
		"max_rank": 3,
		"category": "system",
		"target": "VENT",
		"tags": ["VENT", "HEAT", "KNOCKBACK"],
		"effect": {
			"radius_scale_per_rank": 0.16,
			"force_scale_per_rank": 0.22,
		},
	},
	{
		"id": "VENT_COOLANT",
		"title": "VENT_COOLANT",
		"description": "Shorten VENT cooldown, but reduce the heat retained after venting for heat-threshold effects.",
		"max_rank": 3,
		"category": "system",
		"target": "VENT",
		"tags": ["VENT", "HEAT", "CADENCE"],
		"effect": {
			"cooldown_reduction_per_rank": 0.45,
			"retained_heat_reduction_per_rank": 0.04,
		},
	},
	{
		"id": "OVERCLOCK_KERNEL",
		"title": "OVERCLOCK_KERNEL",
		"description": "All weapon processes execute faster and generate more heat. VENT deals a pulse of damage at high heat.",
		"max_rank": 3,
		"category": "daemon",
		"target": "ALL_PROCESSES",
		"tags": ["HEAT", "CADENCE", "ON_VENT"],
		"effect": {
			"cadence_scale_per_rank": 0.10,
			"heat_scale_per_rank": 0.14,
			"vent_damage_heat_threshold": 0.75,
		},
	},
]


## Returns deep copies so callers may safely add presentation or runtime fields.
static func get_definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.resize(_DEFINITIONS.size())
	for index in range(_DEFINITIONS.size()):
		result[index] = _DEFINITIONS[index].duplicate(true)
	return result


## Returns a deep copy of one definition, or an empty Dictionary for an unknown id.
static func get_definition(upgrade_id: StringName) -> Dictionary:
	var wanted_id := String(upgrade_id)
	for definition in _DEFINITIONS:
		if definition["id"] == wanted_id:
			return definition.duplicate(true)
	return {}


## Returns up to three unique, non-maxed cards in deterministic order.
##
## The same seed, level, ranks, and reroll index always produce the same offer.
## Each returned card is a definition copy with `current_rank`, `next_rank`, and
## `offer_slot` fields appended. If fewer than three legal upgrades remain, all
## remaining upgrades are returned.
static func get_offer(
	run_seed: Variant,
	level_index: int,
	current_upgrades: Dictionary = {},
	reroll_index: int = 0
) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for definition in _DEFINITIONS:
		var current_rank := _rank_for(current_upgrades, String(definition["id"]))
		if current_rank < int(definition["max_rank"]):
			candidates.append(definition)

	var seed_material := "%s|catalog:%d|level:%d|reroll:%d|state:%s" % [
		_seed_to_text(run_seed),
		CATALOG_VERSION,
		level_index,
		reroll_index,
		_rank_signature(current_upgrades),
	]
	var rng_state := _fnv1a_32(seed_material)
	if rng_state == 0:
		rng_state = _NON_ZERO_RNG_SEED

	# Fisher-Yates over the catalog's stable declaration order.
	for index in range(candidates.size() - 1, 0, -1):
		rng_state = _xorshift32(rng_state)
		var swap_index := rng_state % (index + 1)
		var swap_value: Dictionary = candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = swap_value

	var result: Array[Dictionary] = []
	var card_count := mini(OFFER_SIZE, candidates.size())
	for slot in range(card_count):
		var card: Dictionary = candidates[slot].duplicate(true)
		var current_rank := _rank_for(current_upgrades, String(card["id"]))
		card["current_rank"] = current_rank
		card["next_rank"] = current_rank + 1
		card["offer_slot"] = slot
		result.append(card)
	return result


## Public snapshot helper for deterministic tests and run signatures.
static func stable_hash(value: Variant) -> int:
	return _fnv1a_32(_seed_to_text(value))


static func _rank_for(current_upgrades: Dictionary, upgrade_id: String) -> int:
	var value: Variant = current_upgrades.get(upgrade_id, 0)
	if not current_upgrades.has(upgrade_id):
		value = current_upgrades.get(StringName(upgrade_id), 0)
	if value is Dictionary:
		value = value.get("rank", 0)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return maxi(0, int(value))
	return 0


static func _rank_signature(current_upgrades: Dictionary) -> String:
	# Only catalog ranks can affect eligibility, so enumerate the stable catalog
	# instead of relying on Dictionary iteration order.
	var parts := PackedStringArray()
	for definition in _DEFINITIONS:
		parts.append("%s=%d" % [definition["id"], _rank_for(current_upgrades, String(definition["id"]))])
	return ",".join(parts)


static func _seed_to_text(value: Variant) -> String:
	match typeof(value):
		TYPE_INT:
			return "int:%d" % int(value)
		TYPE_STRING, TYPE_STRING_NAME:
			return "text:%s" % String(value)
		TYPE_BOOL:
			return "bool:%s" % ("1" if value else "0")
		TYPE_FLOAT:
			return "float:%s" % String.num(float(value), 12)
		_:
			return "variant:%s" % str(value)


## FNV-1a over UTF-8 bytes. All math is masked to an unsigned 32-bit lane.
static func _fnv1a_32(text: String) -> int:
	var hash_value := _FNV_OFFSET_BASIS
	for byte in text.to_utf8_buffer():
		hash_value = ((hash_value ^ int(byte)) * _FNV_PRIME) & _U32_MASK
	return hash_value


## Small, owned PRNG step used only for deterministic offer shuffling.
static func _xorshift32(state: int) -> int:
	var value := state & _U32_MASK
	value = (value ^ ((value << 13) & _U32_MASK)) & _U32_MASK
	value = (value ^ (value >> 17)) & _U32_MASK
	value = (value ^ ((value << 5) & _U32_MASK)) & _U32_MASK
	if value == 0:
		return _NON_ZERO_RNG_SEED
	return value
