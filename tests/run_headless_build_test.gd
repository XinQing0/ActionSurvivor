extends SceneTree

## Headless checks for build depth: statuses, reactions, augments.
##
## Run it from the repository root:
##
##     godot --headless --fixed-fps 60 --path . --script res://tests/run_headless_build_test.gd
##
## Unlike the smoke and playthrough tests this does not play a run. It builds
## small, controlled situations inside the real main scene (an enemy carrying two
## statuses, a projectile meeting two enemies) and asserts exactly what should
## follow. Every check runs inside a single frame, so no enemy walks, burns down
## or expires between a setup and its assertion.
##
## Fixtures are placed far from the player so the wave director's own enemies
## never fall inside a reaction radius.

const MainScript := preload("res://src/main.gd")
const Enemy := preload("res://src/gameplay/enemy.gd")
const Projectile := preload("res://src/gameplay/spells/projectile.gd")

const FIXTURE_ORIGIN := Vector3(300.0, 0.4, 300.0)

var _main: Node
var _reactions: Node
var _stats: RefCounted
var _failures: Array[String] = []
var _checks := 0
var _ran := false


func _initialize() -> void:
    MainScript.skip_title = true
    MainScript.selected_waves_path = "res://config/waves_demo.json"
    var scene: PackedScene = load("res://src/main.tscn")
    _main = scene.instantiate()
    root.add_child(_main)


func _process(_delta: float) -> bool:
    if _main == null:
        printerr("FAIL: the main scene did not instantiate; check for parse errors above")
        quit(1)
        return true
    if _ran:
        return true
    _ran = true

    _reactions = _main.reactions
    _stats = _main.stats

    _test_status_basics()
    _test_overload()
    _test_shatter()
    _test_steam()
    _test_lockout()
    _test_catalyst()
    _test_brittle_cold()
    _test_wildfire()
    _test_spell_hits_apply_status()
    _test_ricochet()
    _test_backdraft()
    _test_draft_offers_augments()
    _test_augment_grants()

    _report()
    return true


# --- Fixtures -------------------------------------------------------------

func _make_enemy(offset: Vector3, health: float = 500.0) -> Node3D:
    var enemy := Enemy.new()
    enemy.add_to_group("enemies")
    enemy.reactions = _reactions
    enemy.configure({"health": health, "radius": 0.35, "height": 0.8}, null)
    enemy.position = FIXTURE_ORIGIN + offset
    _main.add_child(enemy)
    return enemy


func _clear_fixtures(enemies: Array) -> void:
    for enemy in enemies:
        if is_instance_valid(enemy):
            enemy.remove_from_group("enemies")
            enemy.queue_free()


func _fresh_state() -> void:
    _stats.augments.clear()
    _stats.damage_multiplier = 1.0
    _reactions.counts.clear()


# --- Statuses -------------------------------------------------------------

func _test_status_basics() -> void:
    _fresh_state()
    var enemy := _make_enemy(Vector3.ZERO, 100.0)

    enemy.apply_status("burn", 3.0, 4.0)
    _check(enemy.has_status("burn"), "applying burn marks the enemy as burning")

    enemy.apply_status("burn", 1.0, 2.0)
    _check(is_equal_approx(enemy.get_status_potency("burn"), 4.0), "re-applying keeps the stronger potency")

    enemy._update_statuses(1.0)
    _check(is_equal_approx(enemy.health, 100.0 - 4.0 * 1.0), "burn deals potency damage per second")

    enemy._update_statuses(5.0)
    _check(not enemy.has_status("burn"), "burn expires when its duration runs out")

    var speed_before: float = enemy._speed_factor()
    enemy.apply_status("chill", 2.0, 0.35)
    _check(is_equal_approx(speed_before, 1.0) and is_equal_approx(enemy._speed_factor(), 0.65), "chill slows movement by its potency")

    _clear_fixtures([enemy])


# --- Reactions ------------------------------------------------------------

func _test_overload() -> void:
    _fresh_state()
    var target := _make_enemy(Vector3.ZERO)
    var near := _make_enemy(Vector3(2.0, 0.0, 0.0))
    var far := _make_enemy(Vector3(20.0, 0.0, 0.0))

    target.apply_status("burn", 3.0, 4.0)
    _check(int(_reactions.counts.get("overload", 0)) == 0, "one status alone does not react")
    target.apply_status("shock", 3.0, 1.0)

    _check(int(_reactions.counts.get("overload", 0)) == 1, "burn plus shock fires Overload")
    _check(not target.has_status("burn") and not target.has_status("shock"), "a reaction consumes both statuses")
    _check(is_equal_approx(target.health, 500.0 - 24.0), "Overload damages its target")
    _check(is_equal_approx(near.health, 500.0 - 24.0), "Overload damages enemies inside its radius")
    _check(is_equal_approx(far.health, 500.0), "Overload leaves distant enemies alone")

    _clear_fixtures([target, near, far])


func _test_shatter() -> void:
    _fresh_state()
    var target := _make_enemy(Vector3.ZERO)
    var near := _make_enemy(Vector3(1.5, 0.0, 0.0))

    target.apply_status("chill", 3.0, 0.35)
    target.apply_status("shock", 3.0, 1.0)

    _check(int(_reactions.counts.get("shatter", 0)) == 1, "chill plus shock fires Shatter")
    _check(is_equal_approx(target.health, 500.0 - 48.0), "Shatter is a heavy single-target hit")
    _check(is_equal_approx(near.health, 500.0), "Shatter does not splash")

    _clear_fixtures([target, near])


func _test_steam() -> void:
    _fresh_state()
    var target := _make_enemy(Vector3.ZERO)
    var near := _make_enemy(Vector3(2.0, 0.0, 0.0))

    target.apply_status("burn", 3.0, 4.0)
    target.apply_status("chill", 3.0, 0.35)

    _check(int(_reactions.counts.get("steam", 0)) == 1, "burn plus chill fires Steam")
    _check(near.has_status("chill"), "Steam chills the enemies around it")
    _check(not target.has_status("chill"), "the enemy at the centre is not re-chilled by its own reaction")

    _clear_fixtures([target, near])


func _test_lockout() -> void:
    _fresh_state()
    var target := _make_enemy(Vector3.ZERO)

    target.apply_status("burn", 3.0, 4.0)
    target.apply_status("shock", 3.0, 1.0)
    var health_after_first: float = target.health
    target.apply_status("burn", 3.0, 4.0)
    target.apply_status("shock", 3.0, 1.0)

    _check(int(_reactions.counts.get("overload", 0)) == 1, "an enemy cannot react again during its lockout")
    _check(is_equal_approx(target.health, health_after_first), "a locked-out enemy takes no reaction damage")
    _check(target.has_status("burn") and target.has_status("shock"), "statuses are kept while the lockout holds a reaction back")

    _clear_fixtures([target])


func _test_catalyst() -> void:
    _fresh_state()
    _stats.grant_augment("catalyst", {"damage": 0.5, "radius": 0.25})
    var target := _make_enemy(Vector3.ZERO)
    var outside_base := _make_enemy(Vector3(3.6, 0.0, 0.0))

    target.apply_status("burn", 3.0, 4.0)
    target.apply_status("shock", 3.0, 1.0)

    _check(is_equal_approx(target.health, 500.0 - 24.0 * 1.5), "Catalyst raises reaction damage by 50%")
    _check(outside_base.health < 500.0, "Catalyst widens a reaction past its base radius")

    _clear_fixtures([target, outside_base])


func _test_brittle_cold() -> void:
    _fresh_state()
    var target := _make_enemy(Vector3.ZERO)

    target.apply_status("chill", 3.0, 0.35)
    target.take_damage(10.0)
    _check(is_equal_approx(target.health, 490.0), "chill alone adds no vulnerability")

    _stats.grant_augment("brittle_cold", {"bonus": 0.3})
    target.take_damage(10.0)
    _check(is_equal_approx(target.health, 490.0 - 13.0), "Brittle Cold makes chilled enemies take 30% more")

    var warm := _make_enemy(Vector3(10.0, 0.0, 0.0))
    warm.take_damage(10.0)
    _check(is_equal_approx(warm.health, 490.0), "Brittle Cold does nothing to an enemy that is not chilled")

    _clear_fixtures([target, warm])


func _test_wildfire() -> void:
    _fresh_state()
    _stats.grant_augment("wildfire", {"radius": 3.0, "duration": 3.0})
    var dying := _make_enemy(Vector3.ZERO, 5.0)
    var near := _make_enemy(Vector3(2.0, 0.0, 0.0))
    var far := _make_enemy(Vector3(20.0, 0.0, 0.0))

    dying.apply_status("burn", 3.0, 4.0)
    dying.take_damage(100.0)

    _check(near.has_status("burn"), "a burning enemy's death ignites those beside it")
    _check(is_equal_approx(near.get_status_potency("burn"), 4.0), "the spread fire keeps the strength of the one that died")
    _check(not far.has_status("burn"), "wildfire does not reach distant enemies")

    var cold := _make_enemy(Vector3(40.0, 0.0, 0.0), 5.0)
    var cold_neighbour := _make_enemy(Vector3(41.5, 0.0, 0.0))
    cold.take_damage(100.0)
    _check(not cold_neighbour.has_status("burn"), "an enemy that was not burning spreads nothing")

    _clear_fixtures([dying, near, far, cold, cold_neighbour])


# --- Spell integration ----------------------------------------------------

func _test_spell_hits_apply_status() -> void:
    _fresh_state()
    _main._grant_spell("cinder_nova")
    _main._grant_spell("static_chain")
    _main._grant_spell("warding_orbs")
    var nova: Node = _main._spell_root.get_node("Spell_cinder_nova")
    var chain: Node = _main._spell_root.get_node("Spell_static_chain")
    var orbs: Node = _main._spell_root.get_node("Spell_warding_orbs")

    var enemy := _make_enemy(Vector3.ZERO)
    nova.deal_hit(enemy, 1.0)
    _check(enemy.has_status("burn"), "a fire spell's hit burns the enemy")
    _check(enemy.health < 500.0, "a fire spell's hit also does damage")

    chain.deal_hit(enemy, 1.0)
    _check(int(_reactions.counts.get("overload", 0)) == 1, "landing fire and then lightning triggers Overload through real spells")

    _stats.damage_multiplier = 2.0
    var second := _make_enemy(Vector3(30.0, 0.0, 0.0))
    nova.deal_hit(second, 1.0)
    _check(is_equal_approx(second.get_status_potency("burn"), 8.0), "burn strength scales with the damage multiplier")

    var third := _make_enemy(Vector3(60.0, 0.0, 0.0))
    orbs.deal_hit(third, 1.0)
    _check(third.has_status("chill"), "frost hits chill")

    var killed := _make_enemy(Vector3(90.0, 0.0, 0.0), 1.0)
    nova.deal_hit(killed, 50.0)
    _check(not killed.has_status("burn"), "a killing blow does not apply a status to the dead")

    _clear_fixtures([enemy, second, third, killed])
    _stats.damage_multiplier = 1.0


func _test_ricochet() -> void:
    _fresh_state()
    _main._grant_spell("arc_bolt")
    var bolt: Node = _main._spell_root.get_node("Spell_arc_bolt")
    var first := _make_enemy(Vector3.ZERO)
    var second := _make_enemy(Vector3(4.0, 0.0, 0.0))

    var plain := Projectile.new()
    plain.configure({"damage": 10.0, "projectile_speed": 18.0, "lifetime_seconds": 1.0}, FIXTURE_ORIGIN, Vector3.RIGHT)
    plain.source_spell = bolt
    _main.add_child(plain)
    plain._on_body_entered(first)
    _check(plain.is_queued_for_deletion(), "without Ricochet a bolt ends on its first hit")

    _stats.grant_augment("ricochet", {"bounces": 2, "range": 6.0, "retained": 0.8})
    var rebounding := Projectile.new()
    rebounding.configure(
        {"damage": 10.0, "projectile_speed": 18.0, "lifetime_seconds": 1.0, "bounces": 2, "bounce_range": 6.0, "bounce_retained": 0.8},
        FIXTURE_ORIGIN, Vector3.LEFT
    )
    rebounding.source_spell = bolt
    _main.add_child(rebounding)
    rebounding.global_position = first.global_position
    rebounding._on_body_entered(first)

    _check(not rebounding.is_queued_for_deletion(), "with Ricochet a bolt survives its first hit when another enemy is near")
    _check(rebounding.direction.dot(Vector3.RIGHT) > 0.99, "the rebound turns the bolt towards the other enemy")
    _check(rebounding.bounces == 1, "a rebound spends one bounce")
    _check(is_equal_approx(rebounding.damage, 8.0), "a rebound loses 20% of its damage")

    rebounding._on_body_entered(first)
    _check(rebounding.bounces == 1, "a bolt cannot rebound off the same enemy twice")

    var lonely := Projectile.new()
    lonely.configure({"damage": 10.0, "projectile_speed": 18.0, "lifetime_seconds": 1.0, "bounces": 2}, FIXTURE_ORIGIN, Vector3.LEFT)
    lonely.source_spell = bolt
    _main.add_child(lonely)
    var isolated := _make_enemy(Vector3(100.0, 0.0, 0.0))
    lonely.global_position = isolated.global_position
    lonely._on_body_entered(isolated)
    _check(lonely.is_queued_for_deletion(), "a bolt with nobody to rebound to ends normally")

    _clear_fixtures([first, second, isolated])
    for node in [plain, rebounding, lonely]:
        node.queue_free()


func _test_backdraft() -> void:
    _fresh_state()
    _main._grant_spell("ember_spray")
    var spray: Node = _main._spell_root.get_node("Spell_ember_spray")
    var projectiles: Node = _main.get_node("Projectiles")

    var before := projectiles.get_child_count()
    spray._cast()
    var forward_only := projectiles.get_child_count() - before

    _stats.grant_augment("backdraft", {"rear_fraction": 0.5, "rear_damage": 0.75})
    before = projectiles.get_child_count()
    spray._cast()
    var with_backdraft := projectiles.get_child_count() - before

    _check(with_backdraft > forward_only, "Backdraft fires extra projectiles behind the caster")

    for child in projectiles.get_children():
        child.queue_free()


# --- Draft ----------------------------------------------------------------

func _augment_ids(options: Array[Dictionary]) -> Array[String]:
    var ids: Array[String] = []
    for option in options:
        if str(option.get("kind", "")) == "augment":
            ids.append(str(option.get("id", "")))
    return ids


## Draws repeatedly and collects every augment that ever appears, because a
## single draw only shows three cards.
func _offered_augments(owned: Dictionary, taken: Dictionary) -> Array[String]:
    var seen: Array[String] = []
    for _attempt in range(120):
        for id in _augment_ids(_main._draft.build_options(owned, {}, taken)):
            if not seen.has(id):
                seen.append(id)
    return seen


func _test_draft_offers_augments() -> void:
    var only_bolt := _offered_augments({"arc_bolt": 1}, {})
    _check(only_bolt.has("ricochet"), "owning Arc Bolt unlocks Ricochet")
    _check(not only_bolt.has("twin_pulse") and not only_bolt.has("backdraft"), "augments for spells the player lacks are never offered")
    _check(not only_bolt.has("catalyst") and not only_bolt.has("wildfire"), "reaction and fire augments need the right elements")

    var one_element := _offered_augments({"arc_bolt": 1, "static_chain": 1}, {})
    _check(not one_element.has("catalyst"), "Catalyst needs two different elements, not two spells")

    var two_elements := _offered_augments({"arc_bolt": 1, "cinder_nova": 1}, {})
    _check(two_elements.has("catalyst"), "two elements unlock Catalyst")
    _check(two_elements.has("wildfire"), "a fire spell unlocks Wildfire")

    var after_taking := _offered_augments({"arc_bolt": 1}, {"ricochet": true})
    _check(not after_taking.has("ricochet"), "a taken augment is not offered again")


func _test_augment_grants() -> void:
    _fresh_state()
    _main._taken_augments.clear()
    _main._grant_augment("ricochet")
    _check(_stats.has_augment("ricochet"), "choosing an augment records it on the player's stats")
    _check(is_equal_approx(_stats.augment_param("ricochet", "bounces", 0.0), 2.0), "an augment carries its configured parameters")
    _main._grant_augment("ricochet")
    _check(_main._taken_augments.size() == 1, "an augment cannot be taken twice")
    _check(_main._describe_build().contains("Ricochet"), "the build summary lists augments")
    _main._taken_augments.clear()
    _fresh_state()


# --- Reporting ------------------------------------------------------------

func _report() -> void:
    print("--- headless build test ---")
    print("checks            %d" % _checks)
    if _failures.is_empty():
        print("PASS")
        quit(0)
        return
    for failure in _failures:
        printerr("FAIL: %s" % failure)
    quit(1)


func _check(condition: bool, description: String) -> void:
    _checks += 1
    if not condition:
        _failures.append(description)
