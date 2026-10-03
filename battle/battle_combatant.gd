class_name BattleCombatant
extends RefCounted


var character_name: String = ""
var combat_class: String = ""

var max_hp: int = 0
var hp: int = 0

var max_lp: int = 0
var lp: int = 0

var speed: int = 0

var is_enemy: bool = false
var is_alive: bool = true
var is_guarding: bool = false

var offense_multiplier: float = 1.0
var defense_multiplier: float = 1.0

var defense_buff_turns: int = 0
var offense_buff_turns: int = 0
var defense_debuff_turns: int = 0
var offense_debuff_turns: int = 0

var skill_ids: Array[String] = []


func _init(
	p_name: String,
	p_class: String,
	p_hp: int,
	p_lp: int,
	p_speed: int,
	p_is_enemy: bool
) -> void:
	character_name = p_name
	combat_class = p_class

	max_hp = p_hp
	hp = p_hp

	max_lp = p_lp
	lp = p_lp

	speed = p_speed

	is_enemy = p_is_enemy


func take_damage(amount: int) -> void:
	hp -= amount

	if hp <= 0:
		hp = 0
		is_alive = false


func heal(amount: int) -> void:
	hp = min(
		hp + amount,
		max_hp
	)


func restore_between_rooms() -> void:
	hp = max_hp
	lp = max_lp
	is_alive = true
	is_guarding = false

	offense_multiplier = 1.0
	defense_multiplier = 1.0

	defense_buff_turns = 0
	offense_buff_turns = 0
	defense_debuff_turns = 0
	offense_debuff_turns = 0


func reset_guard() -> void:
	is_guarding = false
