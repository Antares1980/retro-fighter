class_name MobUnit3D
extends Area3D

## Swarm Mob unit for Mob Control 3D.
## Blue mobs multiply through gates and damage the Giant Boss as glowing energy bolts.
## Red mobs march toward the player cannon as articulated 3D humanoid/robot raiders.

@export var team: String = "blue"
@export var speed: float = 9.0

var is_consumed: bool = false
var passed_gates: Dictionary = {}
var hp: int = 1
var power: int = 1:
	set(val):
		power = maxi(0, val)
		hp = power
		_update_power_visuals()

var raider_model: Node3D = null
var left_arm_pivot: Node3D = null
var right_arm_pivot: Node3D = null
var left_leg_pivot: Node3D = null
var right_leg_pivot: Node3D = null
var anim_time: float = 0.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null
@onready var collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null

func _ready() -> void:
	setup(team, power if power > 0 else 1)

func setup(p_team: String, p_power: int = -1) -> void:
	team = p_team
	if p_power > 0:
		power = p_power
	elif power <= 0:
		power = 1
	hp = power
	if mesh_instance == null:
		mesh_instance = get_node_or_null("MeshInstance3D")
	if team == "blue":
		collision_layer = 2
		collision_mask = 28 # Layers 3 (Red), 4 (Gates), 5 (Giant) -> 4 + 8 + 16 = 28
		speed = 9.0
		if mesh_instance != null:
			mesh_instance.visible = true
		if raider_model != null and is_instance_valid(raider_model):
			raider_model.visible = false
		_update_power_visuals()
	else:
		collision_layer = 4
		collision_mask = 2 # Layer 2 (Blue)
		speed = 4.2
		if mesh_instance != null:
			mesh_instance.scale = Vector3.ONE
			mesh_instance.visible = false
		_apply_material(Color("#e62222"))
		_build_raider_model()
		if raider_model != null and is_instance_valid(raider_model):
			raider_model.visible = true

func _build_raider_model() -> void:
	if raider_model != null and is_instance_valid(raider_model):
		return
	raider_model = get_node_or_null("RaiderModel3D") as Node3D
	if raider_model != null:
		return
	raider_model = Node3D.new()
	raider_model.name = "RaiderModel3D"
	add_child(raider_model)

	var armor_mat := StandardMaterial3D.new()
	armor_mat.albedo_color = Color(0.88, 0.14, 0.16, 1.0)
	armor_mat.metallic = 0.35
	armor_mat.roughness = 0.45

	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.28, 0.08, 0.10, 1.0)
	dark_mat.metallic = 0.5
	dark_mat.roughness = 0.4

	var visor_mat := StandardMaterial3D.new()
	visor_mat.albedo_color = Color(1.0, 0.92, 0.25, 1.0)
	visor_mat.emission_enabled = true
	visor_mat.emission = Color(1.0, 0.85, 0.2, 1.0) * 1.4

	var torso := MeshInstance3D.new()
	torso.name = "Torso"
	var torso_mesh := BoxMesh.new()
	torso_mesh.size = Vector3(0.36, 0.36, 0.22)
	torso.mesh = torso_mesh
	torso.material_override = armor_mat
	torso.position = Vector3(0.0, 0.04, 0.0)
	raider_model.add_child(torso)

	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.26, 0.24, 0.24)
	head.mesh = head_mesh
	head.material_override = dark_mat
	head.position = Vector3(0.0, 0.36, 0.0)
	raider_model.add_child(head)

	var visor := MeshInstance3D.new()
	visor.name = "Visor"
	var visor_mesh := BoxMesh.new()
	visor_mesh.size = Vector3(0.22, 0.07, 0.05)
	visor.mesh = visor_mesh
	visor.material_override = visor_mat
	visor.position = Vector3(0.0, 0.37, 0.12)
	raider_model.add_child(visor)

	left_arm_pivot = Node3D.new()
	left_arm_pivot.name = "LeftArmPivot"
	left_arm_pivot.position = Vector3(-0.25, 0.18, 0.0)
	raider_model.add_child(left_arm_pivot)

	var left_arm := MeshInstance3D.new()
	left_arm.name = "LeftArm"
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.11, 0.30, 0.12)
	left_arm.mesh = arm_mesh
	left_arm.material_override = armor_mat
	left_arm.position = Vector3(0.0, -0.12, 0.0)
	left_arm_pivot.add_child(left_arm)

	right_arm_pivot = Node3D.new()
	right_arm_pivot.name = "RightArmPivot"
	right_arm_pivot.position = Vector3(0.25, 0.18, 0.0)
	raider_model.add_child(right_arm_pivot)

	var right_arm := MeshInstance3D.new()
	right_arm.name = "RightArm"
	right_arm.mesh = arm_mesh
	right_arm.material_override = armor_mat
	right_arm.position = Vector3(0.0, -0.12, 0.0)
	right_arm_pivot.add_child(right_arm)

	left_leg_pivot = Node3D.new()
	left_leg_pivot.name = "LeftLegPivot"
	left_leg_pivot.position = Vector3(-0.10, -0.14, 0.0)
	raider_model.add_child(left_leg_pivot)

	var left_leg := MeshInstance3D.new()
	left_leg.name = "LeftLeg"
	var leg_mesh := BoxMesh.new()
	leg_mesh.size = Vector3(0.12, 0.28, 0.14)
	left_leg.mesh = leg_mesh
	left_leg.material_override = dark_mat
	left_leg.position = Vector3(0.0, -0.12, 0.0)
	left_leg_pivot.add_child(left_leg)

	right_leg_pivot = Node3D.new()
	right_leg_pivot.name = "RightLegPivot"
	right_leg_pivot.position = Vector3(0.10, -0.14, 0.0)
	raider_model.add_child(right_leg_pivot)

	var right_leg := MeshInstance3D.new()
	right_leg.name = "RightLeg"
	right_leg.mesh = leg_mesh
	right_leg.material_override = dark_mat
	right_leg.position = Vector3(0.0, -0.12, 0.0)
	right_leg_pivot.add_child(right_leg)

func step_visuals(delta: float) -> void:
	if team != "red":
		return
	if raider_model == null or not is_instance_valid(raider_model):
		_build_raider_model()
	anim_time += delta
	var swing: float = sin(anim_time * 12.0) * 0.55
	if is_instance_valid(left_arm_pivot):
		left_arm_pivot.rotation.x = swing
	if is_instance_valid(right_arm_pivot):
		right_arm_pivot.rotation.x = -swing
	if is_instance_valid(left_leg_pivot):
		left_leg_pivot.rotation.x = -swing
	if is_instance_valid(right_leg_pivot):
		right_leg_pivot.rotation.x = swing
	if is_instance_valid(raider_model):
		raider_model.position.y = abs(sin(anim_time * 12.0)) * 0.05

func get_raider_part_count() -> int:
	if raider_model == null or not is_instance_valid(raider_model):
		return 0
	var count: int = 0
	for child in raider_model.get_children():
		if child is MeshInstance3D:
			count += 1
		for sub in child.get_children():
			if sub is MeshInstance3D:
				count += 1
	return count

func _update_power_visuals() -> void:
	if team != "blue":
		return
	if mesh_instance == null:
		mesh_instance = get_node_or_null("MeshInstance3D")
	if mesh_instance == null:
		return
	if power <= 1:
		mesh_instance.scale = Vector3.ONE
		_apply_material(Color("#1e90ff"))
		return
	var s: float = clampf(1.0 + log(float(power)) * 0.12, 1.0, 1.45)
	mesh_instance.scale = Vector3(s, s, s)
	var t: float = clampf(log(float(power)) / log(25.0), 0.0, 1.0)
	var base_blue := Color("#1e90ff")
	var mid_cyan := Color("#00f2ff")
	var high_gold := Color("#ffd700")
	var tint: Color = base_blue.lerp(mid_cyan, clampf(t * 2.0, 0.0, 1.0)) if t < 0.5 else mid_cyan.lerp(high_gold, clampf((t - 0.5) * 2.0, 0.0, 1.0))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = tint * 0.35
	mesh_instance.material_override = mat

func _apply_material(color: Color) -> void:
	if mesh_instance == null:
		mesh_instance = get_node_or_null("MeshInstance3D")
	if mesh_instance != null:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mesh_instance.material_override = mat

func consume() -> void:
	if is_consumed:
		return
	is_consumed = true
	queue_free()
