class_name ChassisCatalog
extends RefCounted

# Initial bounded tuning targets, not claims of human-validated balance.
const ORDER := ["graviton", "bastion", "scrapper", "redline"]
const SHIPS := {
	"graviton": {"name": "GRAVITON", "attack": "GRAVITON / SWARM RACK", "maneuver": "PHASE SKIP", "summary": "Gather a formation, load missiles, release and drift through the aftermath.", "hull": 100.0, "shield": 30.0, "cruise": 285.0, "thrust": 560.0, "drag": 0.25, "cooling": 22.0, "step": 210.0, "cooldown": 4.2, "protection": 0.22, "color": "b5a0ff"},
	"bastion": {"name": "BASTION", "attack": "SIEGE LANCE", "maneuver": "BREACH STEP", "summary": "Commit to a sustained piercing beam. Heavy inertia rewards a prepared firing lane.", "hull": 145.0, "shield": 45.0, "cruise": 230.0, "thrust": 380.0, "drag": 0.20, "cooling": 22.0, "step": 140.0, "cooldown": 5.0, "protection": 0.30, "color": "ffce80"},
	"scrapper": {"name": "SCRAPPER", "attack": "GRAVITY CLAMP", "maneuver": "TOW STEP", "summary": "Hold an external gathering field. Release its collapse; leave a decoy when escaping.", "hull": 115.0, "shield": 35.0, "cruise": 260.0, "thrust": 470.0, "drag": 0.32, "cooling": 24.0, "step": 165.0, "cooldown": 5.0, "protection": 0.24, "color": "7bdfaa"},
	"redline": {"name": "REDLINE", "attack": "CORONA DRIVE", "maneuver": "BACKTRACE", "summary": "Stay close for heat-amplified plasma pulses. Recall a recent position, never resources.", "hull": 85.0, "shield": 20.0, "cruise": 325.0, "thrust": 760.0, "drag": 0.28, "cooling": 28.0, "step": 350.0, "cooldown": 6.5, "protection": 0.22, "color": "ff7188"},
}


static func get_ship(id: String) -> Dictionary:
	return SHIPS.get(id, SHIPS["graviton"]).duplicate(true)
