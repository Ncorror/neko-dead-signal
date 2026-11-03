extends RefCounted
## One operation wallet shared by factories and construction.

var balance := 0
var total_earned := 0

func credit(amount: int) -> void:
    if amount > 0:
        balance += amount
        total_earned += amount

func spend(amount: int) -> bool:
    if amount <= 0 or balance < amount:
        return false
    balance -= amount
    return true

func refund(amount: int) -> void:
    balance += maxi(0, amount)
