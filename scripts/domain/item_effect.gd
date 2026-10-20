class_name ItemEffect
extends Resource

## Describes one effect.
## Execution belongs to ItemUseResolver.

enum Type {
	RESTORE_HP,
	RESTORE_MP
}

@export var effect_type: Type = Type.RESTORE_HP
@export_range(1, 9999, 1) var amount: int = 1
