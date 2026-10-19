class_name Rules

enum HitKind { BODY, HEAD, MELEE }

const INTERMISSION_SECONDS: float = 10.0
const FIRST_ROUND_DELAY: float = 3.0
const MAX_ALIVE: int = 24

const POINTS_HIT: int = 10
const POINTS_KILL: int = 60
const POINTS_HEADSHOT_KILL: int = 100
const POINTS_MELEE_KILL: int = 130

const PLAYER_MAX_HEALTH: float = 100.0
const PLAYER_REGEN_DELAY: float = 4.0
const PLAYER_REGEN_RATE: float = 50.0

const ZOMBIE_DAMAGE: float = 40.0
const ZOMBIE_ATTACK_RANGE: float = 1.3
const ZOMBIE_ATTACK_COOLDOWN: float = 1.2
const ZOMBIE_HEAD_HEIGHT: float = 1.5
const HEADSHOT_MULTIPLIER: float = 2.0

const MELEE_DAMAGE: float = 150.0
const MELEE_SECONDS: float = 0.6
const MELEE_RANGE: float = 2.0

const WALKER_SPEED: float = 1.6
const JOGGER_SPEED: float = 3.2
const RUNNER_SPEED: float = 5.0

const LOADOUT_SIZE: int = 2
const INTERACT_RANGE: float = 2.5
const SWITCH_SECONDS: float = 0.5
const BOX_PRICE: int = 950
const BOX_ROLL_SECONDS: float = 4.0
const BOX_OFFER_SECONDS: float = 10.0

const UPGRADE_PRICE: int = 4000
const PLAYER_TOUGH_HEALTH: float = 160.0
const MENDER_REGEN_DELAY: float = 1.5
const MENDER_REGEN_RATE: float = 100.0
const RAPID_INTERVAL_FACTOR: float = 0.75
const QUICK_HANDS_FACTOR: float = 0.5

const CACHE_POINTS: int = 1500
## A zombie does not spawn closer to the player than this, if another candidate is farther.
const SPAWN_MIN_DISTANCE: float = 12.0


static func zombie_count(round_number: int) -> int:
	var count: int = 6 + 3 * (round_number - 1)
	if round_number > 5:
		count += floori((round_number - 1) * (round_number - 1) / 4.0)
	return count


static func zombie_health(round_number: int) -> float:
	if round_number <= 9:
		return 150.0 + 100.0 * (round_number - 1)
	return zombie_health(9) * pow(1.1, round_number - 9)


## roll is in [0, 1). The low rolls are runners, then joggers, then walkers.
static func zombie_speed(round_number: int, roll: float) -> float:
	var runner_share: float = clampf((round_number - 3) * 0.12, 0.0, 0.8)
	var jogger_share: float = clampf((round_number - 1) * 0.15, 0.0, 1.0 - runner_share)
	if roll < runner_share:
		return RUNNER_SPEED
	if roll < runner_share + jogger_share:
		return JOGGER_SPEED
	return WALKER_SPEED


static func spawn_interval(round_number: int) -> float:
	return maxf(0.5, 2.0 - 0.15 * (round_number - 1))


static func points_for_hit(killed: bool, kind: HitKind) -> int:
	if not killed:
		return POINTS_HIT
	match kind:
		HitKind.HEAD:
			return POINTS_HEADSHOT_KILL
		HitKind.MELEE:
			return POINTS_MELEE_KILL
	return POINTS_KILL


static func ammo_price(weapon_price: int) -> int:
	return floori(weapon_price / 2.0)


static func max_health(perks: Perks) -> float:
	return PLAYER_TOUGH_HEALTH if perks.has(Perks.Kind.TOUGH) else PLAYER_MAX_HEALTH


static func regen_delay(perks: Perks) -> float:
	return MENDER_REGEN_DELAY if perks.has(Perks.Kind.MENDER) else PLAYER_REGEN_DELAY


static func regen_rate(perks: Perks) -> float:
	return MENDER_REGEN_RATE if perks.has(Perks.Kind.MENDER) else PLAYER_REGEN_RATE


static func fire_interval(def: WeaponDef, perks: Perks) -> float:
	return def.fire_interval * RAPID_INTERVAL_FACTOR if perks.has(Perks.Kind.RAPID) else def.fire_interval


static func reload_seconds(def: WeaponDef, perks: Perks) -> float:
	return def.reload_seconds * QUICK_HANDS_FACTOR if perks.has(Perks.Kind.QUICK_HANDS) else def.reload_seconds


static func switch_seconds(perks: Perks) -> float:
	return SWITCH_SECONDS * QUICK_HANDS_FACTOR if perks.has(Perks.Kind.QUICK_HANDS) else SWITCH_SECONDS


## Of the candidates, the nearest to the player that is at least SPAWN_MIN_DISTANCE away. If every candidate is closer, the farthest one.
static func pick_spawn(candidates: Array[Vector3], player: Vector3) -> Vector3:
	var best: Vector3 = candidates[0]
	var best_far: bool = false
	for candidate: Vector3 in candidates:
		var distance: float = candidate.distance_to(player)
		var far: bool = distance >= SPAWN_MIN_DISTANCE
		var current: float = best.distance_to(player)
		if far and (not best_far or distance < current):
			best = candidate
			best_far = true
		elif not far and not best_far and distance > current:
			best = candidate
	return best
