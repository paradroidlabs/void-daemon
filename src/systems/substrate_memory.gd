class_name SubstrateMemory
extends RefCounted

## Session-only hypotheses from delivered sightings, not build tags or inputs.
const WINDOW := 8.0
const MIN_SAMPLES := 6
var observations: Array[Dictionary] = []
var heading_bin := -1
var confidence := 0.0
var revisions := 0


func observe(velocity: Vector2, time: float) -> void:
	if velocity.length() >= 55:
		var bin := posmod(roundi(velocity.angle() / (TAU / 8)), 8)
		observations.append({"bin": bin, "time": time})
		if observations.size() > 24:
			observations.pop_front()
	advance(time)


func advance(time: float) -> void:
	while not observations.is_empty() and time - float(observations[0]["time"]) > WINDOW:
		observations.pop_front()
	var votes := [0, 0, 0, 0, 0, 0, 0, 0]
	for sample in observations:
		votes[int(sample["bin"])] += 1
	var winner: int = votes.find(votes.max())
	confidence = float(votes[winner]) / maxi(1, observations.size())
	var next := winner if observations.size() >= MIN_SAMPLES and confidence >= 0.67 else -1
	if next != heading_bin:
		revisions += 1
	heading_bin = next


func snapshot() -> Dictionary:
	var votes := [0, 0, 0, 0, 0, 0, 0, 0]
	for sample in observations:
		votes[int(sample["bin"])] += 1
	return {"samples": observations.size(), "heading_bin": heading_bin,
		"confidence": confidence, "revisions": revisions, "votes": votes}
