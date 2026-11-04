extends RefCounted
## Income accrues only during the active operation; power is capacity, not money.

const BASE_POWER := 10
const INCOME_INTERVAL := 5.0
const BASE_INCOME := 2
const EXTRACTOR_INCOME := 10

var income_enabled := true
var enabled := true
var base_age := 0.0
var capacity := BASE_POWER
var demand := 4
var used := 4
var earned := 0

func recalculate(op) -> bool:
    capacity = BASE_POWER
    demand = 0
    used = 0
    for entry in op.construction.buildings:
        if entry["ready"]:
            capacity += int(op.construction.DEFINITIONS[entry["kind"]].get("capacity", 0))
    var changed := false
    for entry in op.construction.buildings:
        var need: int = op.construction.DEFINITIONS[entry["kind"]].get("power", 0)
        var powered: bool = entry["ready"] and used + need <= capacity
        if entry["ready"]:
            demand += need
        if powered:
            used += need
        if bool(entry.get("powered", false)) != powered:
            entry["powered"] = powered
            changed = true
    return changed

func tick(delta: float, op) -> bool:
    if not enabled or op.outcome != op.Outcome.ACTIVE or op.units.is_empty():
        return false
    var changed := recalculate(op)
    if changed:
        op._update_visibility(0.0, true)
    if not income_enabled:
        return changed
    var elapsed := maxf(0.0, delta)
    base_age += elapsed
    var periods := floori((base_age + 0.000001) / INCOME_INTERVAL)
    var income := periods * BASE_INCOME
    base_age = maxf(0.0, base_age - periods * INCOME_INTERVAL)
    for entry in op.construction.buildings:
        if entry["kind"] != &"extractor" or not entry["ready"] or not entry["powered"]:
            continue
        entry["income_age"] = float(entry.get("income_age", 0.0)) + elapsed
        periods = floori((entry["income_age"] + 0.000001) / INCOME_INTERVAL)
        income += periods * EXTRACTOR_INCOME
        entry["income_age"] = maxf(0.0, entry["income_age"] - periods * INCOME_INTERVAL)
    if income > 0:
        op.production.credit(income)
        earned += income
        if RTSDiagnostics.enabled:
            RTSDiagnostics.event("economy", "income", {"amount": income, "balance": op.production.balance,
                "power_used": used, "power_capacity": capacity, "power_demand": demand})
    return changed or income > 0

func powered_extractors(op) -> int:
    var count := 0
    for entry in op.construction.buildings:
        if entry["kind"] == &"extractor" and entry["ready"] and entry.get("powered", false):
            count += 1
    return count

func generators(op) -> int:
    var count := 0
    for entry in op.construction.buildings:
        if entry["kind"] == &"generator" and entry["ready"]:
            count += 1
    return count

func summary() -> String:
    return "ЭНЕРГИЯ: %d/%d%s" % [used, capacity, " · НУЖНО %d" % demand if demand > capacity else ""]

func stop() -> void:
    enabled = false
