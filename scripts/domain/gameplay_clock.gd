class_name GameplayClock
extends RefCounted

## Explicit gameplay time. Never advanced by real time or presentation.

signal advanced(current_tick: int)

var _tick: int = 0
var _exploration_steps: int = 0
var _exploration_quota: int = 1
var _main_squad: Squad

var current_tick: int:
	get:
		return _tick

var exploration_steps: int:
	get:
		return _exploration_steps

var exploration_quota: int:
	get:
		return _exploration_quota


func reset(main_squad: Squad) -> void:
	_main_squad = main_squad
	_tick = 0
	_exploration_steps = 0
	_snapshot_exploration_quota()


func record_exploration_step() -> void:
	if _main_squad == null or not _main_squad.is_alive():
		return

	_exploration_steps += 1

	if _exploration_steps >= _exploration_quota:
		_advance_tick()


func complete_tactical_round() -> void:
	_advance_tick()


func _advance_tick() -> void:
	_tick += 1

	# Every completed global tick begins a new movement interval.
	# Changing rooms or entering alert alone does not reset progress.
	_exploration_steps = 0
	_snapshot_exploration_quota()

	print("[GameplayClock] Tick ", _tick)
	advanced.emit(_tick)


func _snapshot_exploration_quota() -> void:
	_exploration_quota = (
		maxi(1, _main_squad.get_alert_movement_budget())
		if _main_squad != null
		else 1
	)
