class_name EconomyState
extends RefCounted

enum TaxLevel {
	LOW,
	NORMAL,
	HIGH
}

@export var tax_level: TaxLevel = TaxLevel.NORMAL
@export var approval: float = 60.0 # 0.0 to 100.0
@export var last_tax_income: int = 0
@export var last_tax_tick: int = 0
const TAX_INTERVAL_TICKS: int = 40 # Every 10 seconds at 4 ticks/sec

func get_tax_level_name() -> String:
	match tax_level:
		TaxLevel.LOW:
			return "Low"
		TaxLevel.NORMAL:
			return "Normal"
		TaxLevel.HIGH:
			return "High"
		_:
			return "Normal"

func get_tax_rate_per_capita() -> int:
	match tax_level:
		TaxLevel.LOW:
			return 1
		TaxLevel.NORMAL:
			return 2
		TaxLevel.HIGH:
			return 4
		_:
			return 2
