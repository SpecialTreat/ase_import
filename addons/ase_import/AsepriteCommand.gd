@tool
extends RefCounted


const AsepriteKit = preload("AsepriteKit.gd")
const AsepriteJson = preload("AsepriteJson.gd")
const PRINT_THROTTLE_INTERVAL: int = 1000 * 10  # Milliseconds * Seconds


func is_valid_aseprite_command(command: String) -> bool:
	return OS.execute(command, ["--version"]) == OK


func validate_aseprite_command() -> bool:
	var command: String = AsepriteKit.get_aseprite_command()
	if not is_valid_aseprite_command(command):
		return false
	return true


func exec(args: Array, output: Array[String] = []) -> int:
	var command: String = AsepriteKit.get_aseprite_command()
	var stdout: Array = []
	var exit_code: int = OS.execute(command, args, stdout, false, false)
	if stdout:
		output.append_array(stdout[0].strip_edges().split("\n"))
	if exit_code != OK:
		push_error("aseprite error code: %s\n%s\n%s\n%s" % [exit_code, command, args, stdout])
	return exit_code


func list_layers(filename: String, include_hidden_layers: bool = false) -> Array[String]:
	var g_filename: String = ProjectSettings.globalize_path(filename)
	var args = ["--batch", "--list-layers", g_filename]
	if include_hidden_layers:
		args.push_front("--all-layers")
	var output: Array[String] = []
	var exit_code: int = exec(args, output)
	return output


func list_tags(filename: String) -> Array[String]:
	var g_filename: String = ProjectSettings.globalize_path(filename)
	var args: Array = ["--batch", "--list-tags", g_filename]
	var output: Array[String] = []
	var exit_code: int = exec(args, output)
	return output


func is_excluded_pattern(text: String, pattern: String) -> bool:
	if not text or not pattern:
		return false
	var regex = RegEx.new()
	if regex.compile(pattern) != OK:
		push_warning("ERROR: regex: %s" % pattern)
		return false
	return regex.search(text) != null


func list_excluded_layers(filename: String, exclude_layers_pattern: String) -> Array[String]:
	var layers: Array[String] = list_layers(filename)
	return get_excluded_layers(layers, exclude_layers_pattern)


func get_excluded_layers(layers: Array, exclude_layers_pattern: String) -> Array[String]:
	var regex = RegEx.new()
	if regex.compile(exclude_layers_pattern) != OK:
		push_warning("ERROR: regex: %s" % exclude_layers_pattern)
		return []

	var excluded_layers: Array[String] = []
	for layer in layers:
		if regex.search(layer) != null:
			excluded_layers.push_back(layer)
	return excluded_layers


func list_export_spritesheets_results(
	filename: String,
	output_folder: String,
	options: Dictionary
) -> Array[Dictionary]:

	var layers: Array[String] = list_layers(filename, options.get("spritesheets/include_hidden_layers", false))

	var exclude_layers_pattern: String = options.get("spritesheets/exclude_layers_pattern", "")
	var excluded_layers: Array = []
	if exclude_layers_pattern:
		excluded_layers = get_excluded_layers(layers, exclude_layers_pattern)

	var default_layer: String = ""
	for layer in layers:
		if not layer in excluded_layers:
			default_layer = layer
			break

	var tags: Array[String] = list_tags(filename)
	if not tags:
		tags = [""]

	var per_tag_spritesheets: bool = options.get("spritesheets/per_tag", false)
	if not per_tag_spritesheets:
		tags = [tags[0]]

	var filename_pattern: String = options.get("spritesheets/filename_template", "{title}.{extension}")
	var g_output_dir: String = ProjectSettings.globalize_path(output_folder)
	var export_infos: Array[Dictionary] = []
	for tag in tags:
		var export_info: Dictionary = AsepriteKit.aseprite_export_info(filename, default_layer, tag)
		var g_data_file: String = g_output_dir.path_join(AsepriteKit.render_template(filename_pattern, export_info, "json"))
		var g_sprite_sheet: String = g_output_dir.path_join(AsepriteKit.render_template(filename_pattern, export_info, "png"))
		export_info["data_file"] = ProjectSettings.globalize_path(g_data_file)
		export_info["sprite_sheet"] = ProjectSettings.globalize_path(g_sprite_sheet)
		export_infos.append(export_info)
	return export_infos


func export_spritesheets(filename: String, output_folder: String, options: Dictionary) -> Array[Dictionary]:
	var layers: Array[String] = list_layers(filename, options.get("spritesheets/include_hidden_layers", false))

	var exclude_layers_pattern: String = options.get("spritesheets/exclude_layers_pattern", "")
	var excluded_layers: Array[String] = []
	if exclude_layers_pattern:
		excluded_layers = get_excluded_layers(layers, exclude_layers_pattern)

	var default_layer: String = ""
	for layer in layers:
		if not layer in excluded_layers:
			default_layer = layer
			break

	var tags: Array[String] = list_tags(filename)
	if not tags:
		tags = [""]

	var per_tag_spritesheets: bool = options.get("spritesheets/per_tag", false)
	if not per_tag_spritesheets:
		tags = [tags[0]]

	var filename_pattern: String = options.get("spritesheets/filename_template", "{title}.{extension}")
	var g_filename: String = ProjectSettings.globalize_path(filename)
	var g_output_dir: String = ProjectSettings.globalize_path(output_folder)
	var export_infos: Array[Dictionary] = []
	for tag in tags:
		var export_info: Dictionary = AsepriteKit.aseprite_export_info(filename, default_layer, tag)
		var g_data_file: String = g_output_dir.path_join(AsepriteKit.render_template(filename_pattern, export_info, "json"))
		var g_sprite_sheet: String = g_output_dir.path_join(AsepriteKit.render_template(filename_pattern, export_info, "png"))
		var args: Array = [
			"--batch",
			"--list-tags",
			"--list-layers",
			"--filename-format", "{title}-{layer}-{frame}-{tag}-{tagframe}.{extension}",
			"--format", "json-array",
			"--data", g_data_file,
			"--sheet", g_sprite_sheet,
			g_filename
		]

		if options.get("frames/merge_duplicates", true):
			args.push_front("--merge-duplicates")

		if tag and per_tag_spritesheets:
			args.push_front(tag)
			args.push_front("--tag")

		if options.get("spritesheets/include_hidden_layers", false):
			args.push_front("--all-layers")

		if options.get("spritesheets/split_layers", false):
			args.push_front("--split-layers")

		if options.get("frames/trim", false):
			var exclude_trim_pattern: String = options.get("frames/exclude_trim_pattern", "")
			if not is_excluded_pattern(g_sprite_sheet, exclude_trim_pattern):
				args.push_front("--trim")

		var border_padding = str(options.get("frames/border_padding", 0))
		if border_padding and border_padding != "0":
			args.push_front(border_padding)
			args.push_front("--border-padding")

		var shape_padding = str(options.get("frames/shape_padding", 0))
		if shape_padding and shape_padding != "0":
			args.push_front(shape_padding)
			args.push_front("--shape-padding")

		var inner_padding = str(options.get("frames/inner_padding", 0))
		if inner_padding and inner_padding != "0":
			args.push_front(inner_padding)
			args.push_front("--inner-padding")

		var sheet_type = options.get("spritesheets/sheet_type", "packed")
		if sheet_type:
			args.push_front(sheet_type)
			args.push_front("--sheet-type")

		if not excluded_layers.is_empty():
			for excluded_layer in excluded_layers:
				args.push_front(excluded_layer)
				args.push_front("--ignore-layer")

		if exec(args) != OK:
			return []

		export_info["data_file"] = ProjectSettings.localize_path(g_data_file)
		export_info["sprite_sheet"] = ProjectSettings.localize_path(g_sprite_sheet)
		export_infos.append(export_info)
	return export_infos


func list_export_per_layer_results(
	filename: String,
	output_folder: String,
	options: Dictionary
) -> Array[Dictionary]:

	var exclude_layers_pattern: String = options.get("spritesheets/exclude_layers_pattern", "")
	var layers: Array[String] = list_layers(filename, options.get("spritesheets/include_hidden_layers", false))

	var exception_regex: RegEx
	if exclude_layers_pattern != "":
		exception_regex = RegEx.new()
		var err: int = exception_regex.compile(exclude_layers_pattern)
		if err != OK:
			push_error("Error compiling regex for exclude_layers_pattern: %s" % exclude_layers_pattern)
			exception_regex = null

	var export_infos: Array[Dictionary] = []
	for layer in layers:
		if layer != "" and (not exception_regex or exception_regex.search(layer) == null):
			export_infos.append_array(list_export_layer_spritesheets_results(filename, layer, output_folder, options))

	return export_infos


func export_per_layer_spritesheets(
	filename: String,
	output_folder: String,
	options: Dictionary
) -> Array[Dictionary]:

	var exclude_layers_pattern: String = options.get("spritesheets/exclude_layers_pattern", "")
	var layers: Array[String] = list_layers(filename, options.get("spritesheets/include_hidden_layers", false))

	var exception_regex: RegEx
	if exclude_layers_pattern != "":
		exception_regex = RegEx.new()
		if exception_regex.compile(exclude_layers_pattern) != OK:
			push_error("Error compiling regex for exclude_layers_pattern: %s" % exclude_layers_pattern)
			exception_regex = null

	var export_infos: Array[Dictionary] = []
	for layer in layers:
		if layer != "" and (not exception_regex or not exception_regex.search(layer)):
			export_infos.append_array(export_layer_spritesheets(filename, layer, output_folder, options))

	return export_infos


func list_export_layer_spritesheets_results(
	filename: String,
	layer: String,
	output_folder: String,
	options: Dictionary
) -> Array[Dictionary]:

	var tags: Array[String] = list_tags(filename)
	if not tags:
		tags = [""]

	var per_tag_spritesheets: bool = options.get("spritesheets/per_tag", false)
	if not per_tag_spritesheets:
		tags = [tags[0]]

	var filename_pattern: String = options.get("spritesheets/filename_template", "{title}-{layer}.{extension}")
	var g_filename: String = ProjectSettings.globalize_path(filename)
	var g_output_dir: String = ProjectSettings.globalize_path(output_folder)
	var export_infos: Array[Dictionary] = []
	for tag in tags:
		var export_info: Dictionary = AsepriteKit.aseprite_export_info(filename, layer, tag)
		var g_data_file = g_output_dir.path_join(AsepriteKit.render_template(filename_pattern, export_info, "json"))
		var g_sprite_sheet = g_output_dir.path_join(AsepriteKit.render_template(filename_pattern, export_info, "png"))

		export_info["data_file"] = ProjectSettings.localize_path(g_data_file)
		export_info["sprite_sheet"] = ProjectSettings.localize_path(g_sprite_sheet)
		export_infos.append(export_info)
	return export_infos


func export_layer_spritesheets(
	filename: String,
	layer: String,
	output_folder: String,
	options: Dictionary
) -> Array[Dictionary]:

	var tags: Array[String] = list_tags(filename)
	if not tags:
		tags = [""]

	var per_tag_spritesheets = options.get("spritesheets/per_tag", false)
	if not per_tag_spritesheets:
		tags = [tags[0]]

	var filename_pattern: String = options.get("spritesheets/filename_template", "{title}-{layer}.{extension}")
	var g_filename: String = ProjectSettings.globalize_path(filename)
	var g_output_dir: String = ProjectSettings.globalize_path(output_folder)
	var export_infos: Array[Dictionary] = []
	for tag in tags:
		var export_info: Dictionary = AsepriteKit.aseprite_export_info(filename, layer, tag)
		var g_data_file: String = g_output_dir.path_join(AsepriteKit.render_template(filename_pattern, export_info, "json"))
		var g_sprite_sheet: String = g_output_dir.path_join(AsepriteKit.render_template(filename_pattern, export_info, "png"))
		var args = [
			"--batch",
			"--list-tags",
			"--list-layers",
			"--filename-format", "{title}-%s-{frame}-{tag}-{tagframe}.{extension}" % layer,
			"--layer", layer,
			"--data", g_data_file,
			"--format", "json-array",
			"--sheet", g_sprite_sheet,
			g_filename
		]

		if options.get("frames/merge_duplicates", true):
			args.push_front("--merge-duplicates")

		if tag and per_tag_spritesheets:
			args.push_front(tag)
			args.push_front("--tag")

		if options.get("frames/trim", false):
			var exclude_trim_pattern: String = options.get("frames/exclude_trim_pattern", "")
			if not is_excluded_pattern(g_sprite_sheet, exclude_trim_pattern):
				args.push_front("--trim")

		var border_padding = str(options.get("frames/border_padding", 0))
		if border_padding and border_padding != "0":
			args.push_front(border_padding)
			args.push_front("--border-padding")

		var shape_padding = str(options.get("frames/shape_padding", 0))
		if shape_padding and shape_padding != "0":
			args.push_front(shape_padding)
			args.push_front("--shape-padding")

		var inner_padding = str(options.get("frames/inner_padding", 0))
		if inner_padding and inner_padding != "0":
			args.push_front(inner_padding)
			args.push_front("--inner-padding")

		var sheet_type = options.get("spritesheets/sheet_type", "packed")
		if sheet_type:
			args.push_front(sheet_type)
			args.push_front("--sheet-type")

		if exec(args) != OK:
			return []

		export_info["data_file"] = ProjectSettings.localize_path(g_data_file)
		export_info["sprite_sheet"] = ProjectSettings.localize_path(g_sprite_sheet)
		export_infos.append(export_info)
	return export_infos


func list_export_normal_maps_results(export_results: Array, options: Dictionary) -> Array[Dictionary]:
	var normal_map_results: Array[Dictionary] = []
	var regex: RegEx
	var err: int
	var exclude_pattern: String = options.get("normal_maps/exclude_pattern", "")
	if exclude_pattern:
		regex = RegEx.new()
		err = regex.compile(exclude_pattern)
		if err != OK:
			push_error("Aseprite animation importer error [%s]: failed to compile normal map regex pattern, %s" % [err, exclude_pattern])

	for result in export_results:
		if regex and regex.search(result.layer) != null:
#				print("Aseprite animation importer: RegEx(\"%s\") skipping normal map for: %s" % [regex.get_pattern(), result.layer])
			continue

		var normal_image_path: String = "%s_Normal.png" % result.sprite_sheet.get_basename()

		var export_info: Dictionary = result.duplicate(true)
		export_info["normal_map"] = true
		export_info["sprite_sheet"] = normal_image_path
		normal_map_results.append(export_info)
	return normal_map_results


func export_normal_maps(export_results: Array, options: Dictionary) -> Array[Dictionary]:
	var normal_map_results: Array[Dictionary] = []
	var regex: RegEx
	var err: int
	var exclude_pattern: String = options.get("normal_maps/exclude_pattern", "")
	if exclude_pattern:
		regex = RegEx.new()
		err = regex.compile(exclude_pattern)
		if err != OK:
			push_error("Aseprite animation importer error [%s]: failed to compile normal map regex pattern, %s" % [err, exclude_pattern])

	for result in export_results:
		if regex and regex.search(result.layer) != null:
#				print("Aseprite animation importer: RegEx(\"%s\") skipping normal map for: %s" % [regex.get_pattern(), result.layer])
			continue

		var image: Image = Image.new()
		image.load(result.sprite_sheet)
		var normal_image: Image = AsepriteKit.image_to_normal_map(image)
		var normal_image_path: String = "%s_Normal.png" % result.sprite_sheet.get_basename()
		err = normal_image.save_png(normal_image_path)
		if err != OK:
			push_error("Aseprite animation importer error [%s]: failed to save normal map, %s" % [err, normal_image_path])
			continue

		var export_info: Dictionary = result.duplicate(true)
		export_info["normal_map"] = true
		export_info["sprite_sheet"] = normal_image_path
		normal_map_results.append(export_info)
	return normal_map_results


func list_export_occluders_results(export_results: Array, options: Dictionary) -> Array[Dictionary]:
	return []


func export_occluders(export_results: Array, options: Dictionary) -> Array[Dictionary]:
	var occluder_results: Array[Dictionary] = []
	var regex: RegEx
	var err: int
	var exclude_pattern: String = options.get("occluders/exclude_pattern", "")
	if exclude_pattern:
		regex = RegEx.new()
		err = regex.compile(exclude_pattern)
		if err != OK:
			push_error("Aseprite animation importer error [%s]: failed to compile normal occluder regex pattern, %s" % [err, exclude_pattern])

	for result in export_results:
		if result.normal_map:
			continue

		if regex and regex.search(result.layer) != null:
#			print("Aseprite animation importer: RegEx(\"%s\") skipping occluder for: %s" % [regex.get_pattern(), result.layer])
			continue
#		else:
#			print("Aseprite animation importer: RegEx(\"%s\") including occluder for: %s" % [regex.get_pattern(), result.layer])

		var import_data: AsepriteJson = AsepriteJson.new()
		if import_data.load(result.data_file) != OK:
			push_error("Aseprite animation importer error: failed to load json data, %s" % result.data_file)
			continue

		if not(import_data and import_data.json_data):
			push_error("Aseprite animation importer error: missing json data, %s" % result.data_file)
			continue

		var image: Image = Image.new()
		image.load(result.sprite_sheet)

		var track_name_template: String = options.get("occluders/track_name_template", "{layer}_LightOccluder")
		var occluders_node_path: String = AsepriteKit.render_template(track_name_template, result)
		var occluders_node: Node2D = Node2D.new()
		occluders_node.name = occluders_node_path.rsplit("/", false, 1)[-1]
		occluders_node.set_script(preload("AseLightOccluder2D.gd"))

		var existing_polygons: Dictionary = {}

		var updated_frames: Array = []
		for frame in import_data.json_data.frames:
			var frame_rect: Rect2 = Rect2(
				int(frame.frame.x),
				int(frame.frame.y),
				int(frame.frame.w),
				int(frame.frame.h)
			)
			var occluder_node_name: String = frame["filename"].get_basename().replace("/", "__")
			var polygons: Array = AsepriteKit.image_rect_to_occluder_polygons(
				image,
				frame_rect,
				bool(options.get("occluders/include_edges", false)),
				int(options.get("occluders/shrink", 1)),
				int(options.get("occluders/grow", 1)),
				float(options.get("occluders/simplify", 0.1)),
				bool(options.get("occluders/convex_hull", false)),
				bool(options.get("occluders/single_hull", false)),
				int(options.get("occluders/post_shrink", 0)),
				int(options.get("occluders/post_grow", 0))
			)
			if polygons in existing_polygons:
				frame["occluderNode"] = existing_polygons[polygons]
				frame["occluderPolygons"] = polygons
				updated_frames.append(frame)
			else:
				existing_polygons[polygons] = occluder_node_name
				frame["occluderNode"] = occluder_node_name
				frame["occluderPolygons"] = polygons
				updated_frames.append(frame)

				var occluders_container: Node2D
				if frame["occluderPolygons"].size() != 1:
					occluders_container = Node2D.new()
					occluders_container.name = frame["occluderNode"]
					occluders_container.visible = false
					occluders_node.add_child(occluders_container)
					occluders_container.owner = occluders_node

				var index: int = 0
				for dict_polygon in frame["occluderPolygons"]:
					var occluder: LightOccluder2D = LightOccluder2D.new()
					var occluder_polygon: OccluderPolygon2D = OccluderPolygon2D.new()
					occluder_polygon.polygon = AsepriteKit.dict_to_vec_polygon(dict_polygon)
					occluder.occluder = occluder_polygon
					if frame["occluderPolygons"].size() != 1:
						occluder.name = "Occluder%s" % index
						occluders_container.add_child(occluder)
					else:
						occluder.name = frame["occluderNode"]
						occluder.visible = false
						occluders_node.add_child(occluder)
						occluders_container = occluder
					occluder.owner = occluders_node
					index += 1

				# if not occluders_node.active_occluder:
				# 	occluders_node.active_occluder = frame["occluderNode"]

			# Get the center of the frame in the original size
			var source_size : Dictionary = frame.sourceSize
			var source_center_x : float = source_size.w / 2.0
			var source_center_y : float = source_size.h / 2.0

			# Get the center of the trimmed frame in the spritesheet
			var trim_rect : Dictionary = frame.spriteSourceSize
			var trim_rect_center_x : float = trim_rect.x + (trim_rect.w / 2.0)
			var trim_rect_center_y : float = trim_rect.y + (trim_rect.h / 2.0)

			# Calculate the offset between the trimmed frame center and original frame center
			var offset_x := trim_rect_center_x - source_center_x
			var offset_y := trim_rect_center_y - source_center_y
			if options.get("animation/invert_y", false):
				offset_y = -offset_y
			#var offset: = Vector2(offset_x, offset_y)
			frame["occluderNodePosition"] = {"x": offset_x, "y": offset_y}

#				var occluder_image: Image = AsepriteKit.image_rect_to_occluder_image(
#					image,
#					frame_rect,
#					bool(options.get("occluders/include_edges", false)),
#					int(options.get("occluders/shrink", 1)),
#					int(options.get("occluders/grow", 1))
#				)
#				var occluder_texture: ImageTexture = ImageTexture.new()
#				occluder_texture.create_from_image(occluder_image, 0)
#				var occluder_sprite: Sprite = Sprite.new()
#				occluder_sprite.texture = occluder_texture
#				occluder_sprite.name = "Sprite"
#				occluders_container.add_child(occluder_sprite)
#				occluder_sprite.owner = occluders_node

		var occluders_scene: PackedScene = PackedScene.new()
		occluders_scene.pack(occluders_node)
		var occuders_path: String = "%s_LightOccluder.tscn" % result.data_file.get_basename()
		if ResourceSaver.save(occluders_scene, occuders_path, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS) != OK:
			push_error("Aseprite animation importer error: failed to save occluder scene, %s" % result.data_file)
			continue

		import_data.set_frame_array(updated_frames)
		if import_data.save(result.data_file) != OK:
			push_error("Aseprite animation importer error: failed to save occluder json data, %s" % result.data_file)
			continue
	return occluder_results


func list_batch_export_results(
	source_file: String,
	output_folder: String,
	options: Dictionary = {}
) -> Array[Dictionary]:

	if not FileAccess.file_exists(source_file):
		push_error("Aseprite source file not found: %s" % [source_file])
		return []

	if not DirAccess.dir_exists_absolute(output_folder):
		push_error("Aseprite output folder not found: %s" % [output_folder])
		return []

	var per_layer_spritesheets: bool = options.get("spritesheets/per_layer", false)
	var results: Array[Dictionary]
	if per_layer_spritesheets:
		results = list_export_per_layer_results(source_file, output_folder, options)
	else:
		results = list_export_spritesheets_results(source_file, output_folder, options)

	if options.get("normal_maps/enable_generation", false):
		var normal_map_results: Array[Dictionary] = list_export_normal_maps_results(results, options)
		results.append_array(normal_map_results)

	if options.get("occluders/enable_generation", false):
		var occluder_results: Array[Dictionary] = list_export_occluders_results(results, options)
		results.append_array(occluder_results)

	if not results:
		push_error("Aseprite failed to export anything from %s" % source_file)
	return results


func batch_export(
	source_file: String,
	output_folder: String,
	options: Dictionary = {}
) -> Array[Dictionary]:

	if not FileAccess.file_exists(source_file):
		push_error("Aseprite source file not found: %s" % [source_file])
		return []

	if not DirAccess.dir_exists_absolute(output_folder):
		push_error("Aseprite output folder not found: %s" % [output_folder])
		return []

	var per_layer_spritesheets: bool = options.get("spritesheets/per_layer", false)
	var results: Array[Dictionary]
	if per_layer_spritesheets:
		results = export_per_layer_spritesheets(source_file, output_folder, options)
	else:
		results = export_spritesheets(source_file, output_folder, options)

	if options.get("normal_maps/enable_generation", false):
		var normal_map_results: Array[Dictionary] = export_normal_maps(results, options)
		results.append_array(normal_map_results)

	if options.get("occluders/enable_generation", false):
		var occluder_results: Array[Dictionary] = export_occluders(results, options)
		results.append_array(occluder_results)

	if not results:
		push_error("Aseprite failed to export anything from %s" % source_file)
	return results


func export(
	source_file: String,
	save_path: String,
	options: Dictionary,
	r_platform_variants: Array[String],
	r_gen_files: Array[String],
	r_export_results: Array[Dictionary],
) -> int:

	if not validate_aseprite_command():
		return ERR_UNCONFIGURED

	var expected_results: Array[Dictionary] = list_batch_export_results(source_file, source_file.get_base_dir(), options)
	if expected_results.is_empty():
		return FAILED

	var export_results: Array = batch_export(source_file, source_file.get_base_dir(), options)
	if export_results.is_empty():
		push_error("Aseprite import: empty export results")
		return FAILED

	if export_results.size() != expected_results.size():
		push_error("Aseprite import: export results do not match expected export results")
		return FAILED

	r_export_results.append_array(export_results)

	#print("AsepriteCommand.export")
	#print("    source_file: ", source_file)
	#print("    save_path: ", save_path)
	#print("    r_platform_variants: ", r_platform_variants)
	#print("    r_gen_files: ", r_gen_files)
	#print("    r_export_results: ", r_export_results)
	return OK
