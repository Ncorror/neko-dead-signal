extends RefCounted
## Local economy and sequential production. UI never owns resource accounting.

const UNIT_COST := 100
const BUILD_SECONDS := 6.0
const QUEUE_LIMIT := 4

var balance := 0
var total_earned := 0
var completed := 0
var pending: Array[float] = []
var enabled := true
var exit_blocked := false

func credit(amount: int) -> void:
    if amount > 0 and enabled:
        balance += amount
        total_earned += amount

func enqueue() -> bool:
    if not enabled or pending.size() >= QUEUE_LIMIT or balance < UNIT_COST:
        return false
    balance -= UNIT_COST
    pending.append(BUILD_SECONDS)
    return true

func cancel_last() -> bool:
    if not enabled or pending.is_empty():
        return false
    pending.pop_back()
    balance += UNIT_COST
    if pending.is_empty():
        exit_blocked = false
    return true

func tick(delta: float, deploy: Callable) -> int:
    if not enabled:
        return 0
    var budget := maxf(0.0, delta)
    var delivered := 0
    while not pending.is_empty():
        var elapsed := minf(budget, pending[0])
        pending[0] -= elapsed
        budget -= elapsed
        if pending[0] > 0.000001:
            break
        pending[0] = 0.0
        if not bool(deploy.call()):
            exit_blocked = true
            break
        pending.pop_front()
        completed += 1
        delivered += 1
        exit_blocked = false
        if budget <= 0.0:
            break
    return delivered

func stop() -> int:
    if not enabled:
        return 0
    var refunded := pending.size() * UNIT_COST
    balance += refunded
    pending.clear()
    exit_blocked = false
    enabled = false
    return refunded
