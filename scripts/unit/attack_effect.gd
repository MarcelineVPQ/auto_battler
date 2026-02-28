class_name AttackEffect
extends Sprite2D

## Lightweight attack visual — flies from attacker to target, then disappears.
## For melee, spawns at the target and fades out in place.

enum Mode { PROJECTILE, MELEE }

var mode: Mode = Mode.PROJECTILE

static var _textures: Dictionary = {}

static func _load_textures() -> void:
	if not _textures.is_empty():
		return
	_textures = {
		"arrow": preload("res://assets/icons/projectile_arrow.svg"),
		"magic": preload("res://assets/icons/projectile_magic.svg"),
		"holy": preload("res://assets/icons/projectile_holy.svg"),
		"poison": preload("res://assets/icons/projectile_poison.svg"),
		"slash": preload("res://assets/icons/slash.svg"),
		"slash_assassin": preload("res://assets/icons/slash_assassin.svg"),
	}

## Spawn a projectile that flies from start_pos to end_pos
static func spawn_projectile(parent: Node, tex_key: String, start_pos: Vector2, end_pos: Vector2, duration: float = 0.25) -> void:
	_load_textures()
	if not _textures.has(tex_key):
		return
	var fx := AttackEffect.new()
	fx.texture = _textures[tex_key]
	fx.mode = Mode.PROJECTILE
	fx.position = start_pos
	fx.z_index = 10
	# Point toward target
	fx.rotation = start_pos.direction_to(end_pos).angle()
	parent.add_child(fx)
	var tween := fx.create_tween()
	tween.tween_property(fx, "position", end_pos, duration)
	tween.tween_property(fx, "modulate:a", 0.0, 0.08)
	tween.tween_callback(fx.queue_free)

## Spawn a melee slash effect at the target position
static func spawn_slash(parent: Node, tex_key: String, target_pos: Vector2, duration: float = 0.25) -> void:
	_load_textures()
	if not _textures.has(tex_key):
		return
	var fx := AttackEffect.new()
	fx.texture = _textures[tex_key]
	fx.mode = Mode.MELEE
	fx.position = target_pos
	fx.z_index = 10
	fx.scale = Vector2(0.3, 0.3)
	# Random rotation for variety
	fx.rotation = randf() * TAU
	parent.add_child(fx)
	var tween := fx.create_tween()
	tween.tween_property(fx, "scale", Vector2(0.8, 0.8), duration * 0.4)
	tween.parallel().tween_property(fx, "modulate:a", 0.6, duration * 0.4)
	tween.tween_property(fx, "modulate:a", 0.0, duration * 0.6)
	tween.tween_callback(fx.queue_free)
