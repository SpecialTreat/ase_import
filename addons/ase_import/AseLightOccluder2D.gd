@tool
class_name AseLightOccluder2D
extends Node2D


var active_occluder: String = "":
	set(value):
		if has_node(active_occluder):
			get_node(active_occluder).visible = false
		active_occluder = value
		if has_node(active_occluder):
			get_node(active_occluder).visible = true

		# Brute force
		#for node in get_children():
		#	node.visible = node.name == active_occluder
