@tool
class_name AseAnimationTree
extends AnimationTree


static var ANIM_TREE_NODE_REGEX: RegEx = RegEx.new()
static var ANIM_TREE_CONDITION_REGEX: RegEx = RegEx.new()


static func _static_init():
	ANIM_TREE_NODE_REGEX.compile("^(?:nodes|states)/(.+?)/node")
	ANIM_TREE_CONDITION_REGEX.compile("^parameters(?:/|/(.+?)/)conditions/(\\w+)")


static func string_order_by_length_desc(a: String, b: String) -> bool:
	var len_a: int = len(a)
	var len_b: int = len(b)
	if len_a == len_b:
		return a > b
	return len_a > len_b


@export var debug_toggle: bool = false

var animation_player: AnimationPlayer
var transition_params: Dictionary = {
#	"transition_node_name/current": {
#	    "input_name_zero": 0,
#	    "input_name_one": 1,
#	}
}
var transition_params_by_input: Dictionary = {
#	"input_name_zero": "transition_node_name/current",
#	"input_name_one": "transition_node_name/current",
}

var state_machine_nodes: Dictionary = {}
var condition_properties: Dictionary = {}
var condition_property_list: Dictionary = {}
var parameter_properties: Dictionary = {}
var animation_playbacks: Dictionary = {}


func _ready():
	if tree_root is AnimationNodeStateMachine:
		state_machine_nodes[""] = tree_root

	_collect_animation_nodes(tree_root, "")
	_collect_animation_parameters()

	reset_conditions()

	animation_player = get_node(anim_player)
	if not Engine.is_editor_hint():
		active = true

	#print("state_machine_nodes")
	#print(JSON.stringify(state_machine_nodes, "    "))
	#print("\n")

	#print("animation_playbacks")
	#print(JSON.stringify(animation_playbacks, "    "))
	#print("\n")

	#print("condition_properties")
	#print(JSON.stringify(condition_properties, "    "))
	#print("\n")

	#print("condition_property_list")
	#print(JSON.stringify(condition_property_list, "    "))
	#print("\n")

	#print("parameter_properties")
	#print(JSON.stringify(parameter_properties, "    "))
	#print("\n")


func _collect_animation_nodes(root: AnimationNode, path: String):
	var tree_properties: Array[Dictionary] = root.get_property_list()
	for prop in tree_properties:
		var prop_name: String = prop["name"]
		var result: RegExMatch = ANIM_TREE_NODE_REGEX.search(prop_name)
		if result:
			var node_name: String = result.get_string(1)
			var anim_node: AnimationNode = root.get_node(node_name)
			if anim_node is AnimationNodeTransition:
				var transition_param: String = "parameters/%s/current" % node_name
				transition_params[transition_param] = {}
				var index: int = 0
				var input_count: int = anim_node.get_input_count()
				while index < input_count:
					var transition_name: String = anim_node.get_input_name(index)
					anim_node.set_meta(transition_name, index)
					transition_params[transition_param][transition_name] = index
					transition_params_by_input[transition_name] = transition_param
					index += 1

			elif anim_node is AnimationNodeStateMachine:
				var node_path: String = path.path_join(node_name) if path else node_name
				state_machine_nodes[node_path] = anim_node
				_collect_animation_nodes(anim_node, node_path)

			elif node_name != "End" and node_name != "Start":
				var playback_path: String = "parameters/%s/playback" % path if path else "parameters/playback"
				if playback_path in self:
					animation_playbacks[node_name] = get(playback_path)


func _collect_animation_parameters():
	var param_regex: RegEx = RegEx.new()
	var names: Array = state_machine_nodes.keys().filter(func(s): return s != "")
	names.sort_custom(string_order_by_length_desc)
	var names_pattern: String = "|".join(names)
	var pattern: String = "^parameters(?:/(%s)/|/)(.+)$" % names_pattern
	param_regex.compile(pattern)

	for prop in get_property_list():
		var prop_name: String = prop["name"]
		var result: RegExMatch = ANIM_TREE_CONDITION_REGEX.search(prop_name)
		if result:
			var condition: String = result.get_string(2)
			if condition in condition_properties:
				if not condition_properties[condition].has(prop_name):
					condition_properties[condition].append(prop_name)
			else:
				condition_properties[condition] = [prop_name]
		else:
			result = param_regex.search(prop_name)
			if result:
				var param: String = result.get_string(2)
				if param != "playback":
					parameter_properties[param] = prop_name

	condition_property_list = {}
	for condition in condition_properties.keys():
		var root_prop: String = "parameters/conditions".path_join(condition)
		if not condition_properties[condition].has(root_prop):
			condition_properties[condition].append(root_prop)

		condition_property_list[condition] = {
			"name": root_prop,
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "",
		}

		condition = condition.substr(4) if condition.begins_with("not_") else "not_" + condition
		root_prop = "parameters/conditions".path_join(condition)
		if condition_properties.has(condition):
			if not condition_properties[condition].has(root_prop):
				condition_properties[condition].append(root_prop)

		condition_property_list[condition] = {
			"name": root_prop,
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "",
		}
	notify_property_list_changed()


func _get_property_list():
	return condition_property_list.values()


func debug_animation(animation_type: String, animation_name: String) -> void:
	if not debug_toggle or not OS.is_debug_build():
		return

	print("anim_", animation_type, " [", Engine.get_physics_frames(), "]: ", get_parent().name, ".", animation_name)


func debug_condition_change(condition: String, value: bool) -> void:
	if not debug_toggle or not OS.is_debug_build():
		return

	var display_condition: String = condition
	var display_value: bool = value

	if not condition in condition_properties:
		condition = condition.substr(4) if condition.begins_with("not_") else "not_" + condition
		value = not value

	if not condition in condition_properties:
		return

	for prop in condition_properties[condition]:
		if get(prop) != null:
			if not not get(prop) != value:
				print("anim_condition [", Engine.get_physics_frames(), "]: ", get_parent().name, ".", display_condition, " = ", display_value)
			break


func debug_parameter_change(parameter: String, value: bool) -> void:
	if not debug_toggle or not OS.is_debug_build():
		return

	var prop: String = "parameters/" + parameter
	if get(prop) != null:
		if not not get(prop) != value:
			print("anim_parameter [", Engine.get_physics_frames(), "]: ", get_parent().name, ".", parameter, " = ", value)


func get_playback(animation_name: StringName) -> AnimationNodeStateMachinePlayback:
	return animation_playbacks[animation_name]


func has_playback(animation_name: StringName) -> bool:
	return animation_name in animation_playbacks


func get_animation_time(animation_name: StringName) -> float:
	if animation_player:
		var animation: Animation = animation_player.get_animation(animation_name)
		if animation:
			return animation.length
	return -1.0


func start(animation_name: StringName, conditions: Dictionary = {}, duration: float = -1.0, advance_by: float = -1.0) -> void:
	set_conditions(conditions, duration, advance_by)
	debug_animation("start", animation_name)
	if has_playback(animation_name):
		get_playback(animation_name).start(animation_name)

	elif animation_name in transition_params_by_input:
		var param: String = transition_params_by_input[animation_name]
		set(param, transition_params[param][animation_name])

	else:
		push_warning("[SKIPPED] anim_start: %s.%s" % [get_parent().name, animation_name])


func restart(animation_name: StringName, conditions: Dictionary = {}, duration: float = -1.0, advance_by: float = -1.0) -> void:
	set_conditions(conditions, duration, advance_by)
	debug_animation("restart", animation_name)
	if has_playback(animation_name):
		var playback: AnimationNodeStateMachinePlayback = get_playback(animation_name)
		if playback.get_current_node() == animation_name:
			playback.stop()
			animation_player.stop(true)
		playback.start(animation_name)

	elif animation_name in transition_params_by_input:
		var param: String = transition_params_by_input[animation_name]
		set(param, transition_params[param][animation_name])

	else:
		push_warning("[SKIPPED] anim_restart: %s.%s" % [get_parent().name, animation_name])



func travel(animation_name: StringName, conditions: Dictionary = {}, duration: float = -1.0, advance_by: float = -1.0) -> void:
	set_conditions(conditions, duration, advance_by)
	debug_animation("travel", animation_name)
	if has_playback(animation_name):
		get_playback(animation_name).travel(animation_name)

	elif animation_name in transition_params_by_input:
		var param: String = transition_params_by_input[animation_name]
		set(param, transition_params[param][animation_name])

	else:
		push_warning("[SKIPPED] anim_travel: %s.%s" % [get_parent().name, animation_name])


func retravel(animation_name: StringName, conditions: Dictionary = {}, duration: float = -1.0, advance_by: float = -1.0) -> void:
	set_conditions(conditions, duration, advance_by)
	debug_animation("retravel", animation_name)
	if has_playback(animation_name):
		var playback: AnimationNodeStateMachinePlayback = get_playback(animation_name)
		if playback.get_current_node() == animation_name:
			playback.stop()
			animation_player.stop(true)
			playback.start(animation_name)
		else:
			playback.travel(animation_name)

	else:
		push_warning("[SKIPPED] anim_retravel: %s.%s" % [get_parent().name, animation_name])


func reset_conditions():
	for condition in condition_properties:
		for prop in condition_properties[condition]:
			set(prop, condition.begins_with("not_"))


func set_conditions(conditions: Dictionary, duration: float = -1.0, advance_by: float = -1.0) -> void:
	for condition in conditions:
		set_condition(condition, conditions[condition], duration, advance_by)


func set_condition(condition: String, value: bool, duration: float = -1.0, advance_by: float = -1.0) -> void:
	debug_condition_change(condition, value)

	if condition in condition_properties:
		for prop in condition_properties[condition]:
			set(prop, value)

	var not_condition: String = "not_" + condition
	if not_condition in condition_properties:
		for prop in condition_properties[not_condition]:
			set(prop, not value)

	if advance_by >= 0.0:
		advance(advance_by)

	if duration > 0.0:
		if is_inside_tree():
			await get_tree().create_timer(duration).timeout
		if is_inside_tree():
			debug_condition_change(condition, not value)
			if condition in condition_properties:
				for prop in condition_properties[condition]:
					set(prop, not value)

			if not_condition in condition_properties:
				for prop in condition_properties[not_condition]:
					set(prop, value)


func set_parameters(parameters: Dictionary) -> void:
	for parameter in parameters:
		set_parameter(parameter, parameters[parameter])


func set_parameter(parameter: String, value) -> void:
	debug_parameter_change(parameter, value)

	if parameter in transition_params:
		var inputs_by_name: Dictionary = transition_params[parameter]
		if value in inputs_by_name:
			set("parameters/" + parameter, inputs_by_name[value])
			return

	elif parameter in parameter_properties:
		set(parameter_properties[parameter], value)
