@tool
class_name AseAnimationPlayer
extends AnimationPlayer


@export var import_animation_library_name: String = "<import>":
	set(value):
		if Engine.is_editor_hint():
			if value != import_animation_library_name:
				if has_animation_library(import_animation_library_name):
					if is_playing():
						stop()
					if has_animation_library(value):
						remove_animation_library(value)
					rename_animation_library(import_animation_library_name, value)
		import_animation_library_name = value

@export var import_animation_library: AnimationLibrary:
	set(value):
		if Engine.is_editor_hint():
			if is_playing():
				stop()
			if has_animation_library(import_animation_library_name):
				remove_animation_library(import_animation_library_name)
			if value:
				add_animation_library(import_animation_library_name, value)
		import_animation_library = value
