@tool
extends EditorPlugin


const ImportPlugin_Texture2D: GDScript = preload("ImportPlugin_Texture2D.gd")
const ImportPlugin_SpriteFrames: GDScript = preload("ImportPlugin_SpriteFrames.gd")
const ImportPlugin_AnimationLibrary: GDScript = preload("ImportPlugin_AnimationLibrary.gd")
const Type_AseAnimationPlayer: GDScript = preload("AseAnimationPlayer.gd")
const Type_AseAnimationTree: GDScript = preload("AseAnimationTree.gd")
const Type_AseLightOccluder2D: GDScript = preload("AseLightOccluder2D.gd")
const SETTING_COMMAND_PATH: StringName = &"aseprite/importer/command_path"


var import_plugin_texture2D: EditorImportPlugin
var import_plugin_sprite_frames: EditorImportPlugin
var import_plugin_animation_library: EditorImportPlugin


func _enter_tree():
	add_project_settings()

	import_plugin_texture2D = ImportPlugin_Texture2D.new()
	import_plugin_sprite_frames = ImportPlugin_SpriteFrames.new()
	import_plugin_animation_library = ImportPlugin_AnimationLibrary.new()

	add_custom_type("AseAnimationPlayer", "AnimationPlayer", Type_AseAnimationPlayer, get_editor_icon(&"AnimationPlayer"))
	add_custom_type("AseAnimationTree", "AnimationTree", Type_AseAnimationTree, get_editor_icon(&"AnimationTree"))
	add_custom_type("AseLightOccluder2D", "Node2D", Type_AseLightOccluder2D, get_editor_icon(&"LightOccluder2D"))
	add_import_plugin(import_plugin_texture2D)
	add_import_plugin(import_plugin_sprite_frames)
	add_import_plugin(import_plugin_animation_library)



func _exit_tree():
	remove_import_plugin(import_plugin_texture2D)
	remove_import_plugin(import_plugin_sprite_frames)
	remove_import_plugin(import_plugin_animation_library)
	remove_custom_type("AseLightOccluder2D")
	remove_custom_type("AseAnimationTree")
	remove_custom_type("AseAnimationPlayer")

	import_plugin_texture2D = null
	import_plugin_sprite_frames = null
	import_plugin_animation_library = null

	remove_project_settings()


func add_project_settings():
	var default_command_path: String = get_default_aseprite_command_path()
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	if not editor_settings.has_setting(SETTING_COMMAND_PATH):
		editor_settings.set_setting(SETTING_COMMAND_PATH, default_command_path)
	editor_settings.set_initial_value(SETTING_COMMAND_PATH, default_command_path, false)
	editor_settings.add_property_info({
		"name": SETTING_COMMAND_PATH,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_FILE,
		"hint_string": "",
	})


func remove_project_settings():
	# Don't remove the setting if the user manually updated it
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	if editor_settings.has_setting(SETTING_COMMAND_PATH):
		var default_command_path: String = get_default_aseprite_command_path()
		if editor_settings.get_setting(SETTING_COMMAND_PATH) == default_command_path:
			editor_settings.erase(SETTING_COMMAND_PATH)


func get_editor_icon(type_name: StringName) -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon(type_name, &"EditorIcons")


func get_default_aseprite_command_path() -> String:
	if OS.get_name() == "macOS" or OS.get_name() == "OSX":
		return "/Applications/Aseprite.app/Contents/MacOS/aseprite"
	elif OS.get_name() == "Windows":
		for file_path in [
			"C:/Program Files/Aseprite/Aseprite.exe",
			"C:/Program Files (x86)/Aseprite/Aseprite.exe",
		]:
			if FileAccess.file_exists(file_path):
				return file_path
		return "C:/Program Files/Aseprite/Aseprite.exe"
	else:
		var stdout: Array = []
		var exit_code: int = OS.execute("which", ["aseprite"], stdout, false, false)
		if exit_code == OK:
			return "".join(stdout)
	return "aseprite"
