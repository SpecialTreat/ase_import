@tool
extends RefCounted


enum Presets {
	DEFAULT,
}

const SETTING_ASEPRITE_COMMAND_PATH: StringName = &"aseprite/importer/command_path"
const SQRT_TWO: float = 1.4142135624

const IMPORT_OPTIONS_DEFAULT: Array[Dictionary] = [
	# Spritesheets
	{"name": "spritesheets/per_layer", "default_value": true},
	{"name": "spritesheets/per_tag", "default_value": false},
	{"name": "spritesheets/include_hidden_layers", "default_value": false},
	{"name": "spritesheets/exclude_layers_pattern", "default_value": "^_"},
	{"name": "spritesheets/split_layers", "default_value": false},
	{
		"name": "spritesheets/sheet_type",
		"default_value": "packed",
		"property_hint": PROPERTY_HINT_ENUM,
		"hint_string": "horizontal,vertical,rows,columns,packed"
	},
	{"name": "spritesheets/filename_template", "default_value": "{title}-{layer}.{extension}"},

	# Frames Options
	{"name": "frames/trim", "default_value": true},
	{"name": "frames/exclude_trim_pattern", "default_value": ""},
	{"name": "frames/border_padding", "default_value": 0},
	{"name": "frames/shape_padding", "default_value": 0},
	{"name": "frames/inner_padding", "default_value": 0},
	{"name": "frames/merge_duplicates", "default_value": true},

	# Animation Options
	{"name": "animation/fps_snap", "default_value": -1.0},
	{"name": "animation/invert_y", "default_value": false},
	{"name": "animation/track_name_template", "default_value": "{layer}"},

	# Animate Position Options
	{"name": "animate_position/enabled", "default_value": false},
	{"name": "animate_position/include_pattern", "default_value": ".*Marker.*"},
	{"name": "animate_position/pixel_scale", "default_value": 0.05},
	{"name": "animate_position/use_vector3", "default_value": false},

	# Normal Map Options
	{"name": "normal_maps/enable_generation", "default_value": false},
	{"name": "normal_maps/exclude_pattern", "default_value": "^_"},

	# Occluder Options
	{"name": "occluders/enable_generation", "default_value": false},
	{"name": "occluders/exclude_pattern", "default_value": "^_"},
	{"name": "occluders/include_edges", "default_value": false},
	{"name": "occluders/shrink", "default_value": 0},
	{"name": "occluders/grow", "default_value": 0},
	{"name": "occluders/post_shrink", "default_value": 0},
	{"name": "occluders/post_grow", "default_value": 0},
	{"name": "occluders/simplify", "default_value": 0.1},
	{"name": "occluders/convex_hull", "default_value": false},
	{"name": "occluders/single_hull", "default_value": true},
	{"name": "occluders/track_name_template", "default_value": "{layer}_LightOccluder"},
]


static func get_aseprite_command() -> String:
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	return editor_settings.get_setting(SETTING_ASEPRITE_COMMAND_PATH)


static var has_aborted: bool = false


static func print_invalid_aseprite_command():
	if not has_aborted:
		var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
		has_aborted = true
		print("""
Invalid Aseprite command: '%s'
	Set the Aseprite command in Editor Settings:
		Editor > Editor Settings... > Aseprite > Importer > Command Path
""" % editor_settings.get_setting(SETTING_ASEPRITE_COMMAND_PATH)
		)


static func dict_to_vec_polygon(dict_polygon: Array) -> PackedVector2Array:
	var vec_polygon: PackedVector2Array = PackedVector2Array()
	for dict in dict_polygon:
		vec_polygon.append(Vector2(dict["x"], dict["y"]))
	return vec_polygon


static func vec_to_dict_polygon(vec_polygon: PackedVector2Array) -> Array:
	var dict_polygon: Array = Array()
	for vec in vec_polygon:
		dict_polygon.append({"x": vec.x, "y": vec.y})
	return dict_polygon


static func translate_vec_polygon(vec_polygon: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var polygon: PackedVector2Array = PackedVector2Array()
	for vec in vec_polygon:
		polygon.append(vec + offset)
	return polygon


static func image_to_occluder_polygons(image: Image, include_edges: bool, shrink: int, grow: int, simplify: float, convex: bool, post_shrink: int, post_grow: int) -> Array:
	var rect: Rect2 = Rect2(Vector2.ZERO, image.get_size())
	return image_rect_to_occluder_polygons(image, rect, include_edges, shrink, grow, simplify, convex, post_shrink, post_grow)


static func image_rect_to_occluder_polygons(image: Image, rect: Rect2, include_edges: bool, shrink: int, grow: int, simplify: float, convex: bool, single_hull: bool = true, post_shrink: int = 0, post_grow: int = 0) -> Array:
	var bitmap: BitMap = image_rect_to_occluder_bitmap(image, rect, include_edges, shrink, grow)
	var polygons: Array = bitmap.opaque_to_polygons(Rect2(Vector2.ZERO, rect.size), simplify)

	if post_shrink != 0:
		var modified_polygons: Array = []
		for polygon in polygons:
			modified_polygons.append_array(Geometry2D.offset_polygon(polygon, float(-post_shrink), Geometry2D.JOIN_MITER))
		polygons = modified_polygons

	if post_grow != 0:
		var modified_polygons: Array = []
		for polygon in polygons:
			modified_polygons.append_array(Geometry2D.offset_polygon(polygon, float(post_grow), Geometry2D.JOIN_MITER))
		polygons = modified_polygons

	if convex:
		if single_hull:
			var point_cloud: Array = []
			for polygon in polygons:
				point_cloud.append_array(polygon)
			polygons = [Array(Geometry2D.convex_hull(point_cloud))]
		else:
			var convex_polygons: Array = []
			for polygon in polygons:
				convex_polygons.append(Array(Geometry2D.convex_hull(polygon)))
			polygons = convex_polygons

	var dict_polygons: Array = []
	for polygon in polygons:
		dict_polygons.append(vec_to_dict_polygon(translate_vec_polygon(polygon, - rect.size * 0.5)))
	return dict_polygons


static func image_to_occluder_image(image: Image, include_edges: bool, shrink: int, grow: int) -> Image:
	var rect: Rect2 = Rect2(Vector2.ZERO, image.get_size())
	return image_rect_to_occluder_image(image, rect, include_edges, shrink, grow)


static func image_rect_to_occluder_image(image: Image, rect: Rect2, include_edges: bool, shrink: int, grow: int) -> Image:
	var width: = int(rect.size.x)
	var height: = int(rect.size.y)
	var bitmap: = image_rect_to_occluder_bitmap(image, rect, include_edges, shrink, grow)

	var occluder: = Image.new()
	occluder.create(width, height, false, Image.FORMAT_RGBA8)
	for x in range(width):
		for y in range(height):
			if bitmap.get_bit(x, y):
				occluder.set_pixel(x, y, Color.WHITE)
			else:
				occluder.set_pixel(x, y, Color.TRANSPARENT)
	return occluder


static func image_to_occluder_bitmap(image: Image, include_edges: bool, shrink: int, grow: int) -> BitMap:
	var rect: Rect2 = Rect2(Vector2.ZERO, image.get_size())
	return image_rect_to_occluder_bitmap(image, rect, include_edges, shrink, grow)


static func image_rect_to_occluder_bitmap(image: Image, rect: Rect2, include_edges: bool, shrink: int, grow: int) -> BitMap:
	var width: = int(rect.size.x)
	var height: = int(rect.size.y)
	var maxx: int = width - 1
	var maxy: int = height - 1

	var bitmap: BitMap = BitMap.new()
	bitmap.create(rect.size)

	for x in range(width):
		for y in range(height):
			var x_img: int = x + int(rect.position.x)
			var y_img: int = y + int(rect.position.y)

			if image.get_pixel(x_img, y_img).a8 == 255:
				# Detect Edges around pixel
				bitmap.set_bit(x, y, true)
				if include_edges:
					continue

				if x == 0 or y == 0 or x == maxx or y == maxy:
					bitmap.set_bit(x, y, false)

				# top left
				if image.get_pixel(x_img - 1, y_img - 1).a8 < 255:
					bitmap.set_bit(x, y, false)

				# top
				if image.get_pixel(x_img, y_img - 1).a8 < 255:
					bitmap.set_bit(x, y, false)

				# top right
				if image.get_pixel(x_img + 1, y_img - 1).a8 < 255:
					bitmap.set_bit(x, y, false)

				# left
				if image.get_pixel(x_img - 1, y_img).a8 < 255:
					bitmap.set_bit(x, y, false)

				# right
				if image.get_pixel(x_img + 1, y_img).a8 < 255:
					bitmap.set_bit(x, y, false)

				# bottom left
				if image.get_pixel(x_img - 1, y_img + 1).a8 < 255:
					bitmap.set_bit(x, y, false)

				# bottom
				if image.get_pixel(x_img, y_img + 1).a8 < 255:
					bitmap.set_bit(x, y, false)

				# bottom right
				if image.get_pixel(x_img + 1, y_img + 1).a8 < 255:
					bitmap.set_bit(x, y, false)

	if shrink != 0:
		bitmap.grow_mask(-shrink, Rect2(Vector2.ZERO, rect.size))
	if grow != 0:
		bitmap.grow_mask(grow, Rect2(Vector2.ZERO, rect.size))

	return bitmap


static func image_to_normal_map(image: Image, normal_height: float = SQRT_TWO, invert_y: bool = true) -> Image:
	var width: = image.get_width()
	var height: = image.get_height()
	var maxx: int = width - 1
	var maxy: int = height - 1

	var normal_map: = Image.new()
	normal_map.create(width, height, false, Image.FORMAT_RGBA8)

	for x in range(width):
		for y in range(height):
			normal_map.set_pixel(x, y, Color.TRANSPARENT)
			if image.get_pixel(x, y).a8 == 255:
				# Detect Edges around pixel
				var x_dir: float = 0
				var y_dir: float = 0

				# top left
				if (x == 0 and y == 0) or (x > 0 and y > 0 and image.get_pixel(x - 1, y - 1).a8 < 255):
					x_dir -= 1.0
					y_dir -= 1.0

				# top
				if (y == 0) or (image.get_pixel(x, y - 1).a8 < 255):
					y_dir -= SQRT_TWO

				# top right
				if (x == maxx and y == 0) or (x < maxx and y > 0 and image.get_pixel(x + 1, y - 1).a8 < 255):
					x_dir += 1.0
					y_dir -= 1.0

				# left
				if (x == 0) or (image.get_pixel(x - 1, y).a8 < 255):
					x_dir -= SQRT_TWO

				# right
				if (x == maxx) or (image.get_pixel(x + 1, y).a8 < 255):
					x_dir += SQRT_TWO

				# bottom left
				if (x == 0 and y == maxy) or (x > 0 and y < maxy and image.get_pixel(x - 1, y + 1).a8 < 255):
					# Removed x_dir to give lower corners of sprite slight downward bias
					# x_dir -= 1.0
					y_dir += 1.0

				# bottom
				if (y == maxy) or (image.get_pixel(x, y + 1).a8 < 255):
					y_dir += SQRT_TWO

				# bottom right
				if (x == maxx and y == maxy) or (x < maxx and y < maxy and image.get_pixel(x + 1, y + 1).a8 < 255):
					# Removed x_dir to give lower corners of sprite slight downward bias
					# x_dir += 1.0
					y_dir += 1.0

				# process pixels that have a valid direction
				var normalization: float = sqrt(x_dir * x_dir + y_dir * y_dir + normal_height * normal_height)
				var x_normal: = float(x_dir) / normalization
				var y_normal: = float(-y_dir) / normalization
				if invert_y:
					y_normal = -y_normal

				var z_normal: = float(normal_height) / normalization

				# convert direction into color
				var normal_color: Color = Color()
				normal_color.r8 = int(floor((x_normal * 0.5 + 0.5) * 255.0))
				normal_color.g8 = int(floor((y_normal * 0.5 + 0.5) * 255.0))
				normal_color.b8 = int(floor((z_normal * 0.5 + 0.5) * 255.0))
				normal_color.a8 = 255

#				print("(%.3f, %.3f, %.3f) >> #%s" % [x_normal, y_normal, z_normal, normal_color.to_html()])

				normal_map.set_pixel(x, y, normal_color)

	return normal_map


static func clear_dir(path: String) -> DirAccess:
	DirAccess.make_dir_recursive_absolute(path)
	var dir: DirAccess = DirAccess.open(path)
	dir.include_hidden = true
	dir.include_navigational = false
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			dir.remove(file_name)
		file_name = dir.get_next()
	return dir


static func replace_all(text: String, replacements: Dictionary) -> String:
	for k in replacements:
		text = text.replace(k, replacements[k])
	return text


static func aseprite_export_info(filename: String, layer: String = "", tag: String = "") -> Dictionary:
	return {
		"fullname": filename,
		"path": filename.get_base_dir(),
		"name": filename.get_file(),
		"title": filename.get_basename().get_file(),
		"layer": layer,
		"tag": tag,
		"normal_map": false,
	}


static func render_template(pattern: String, export_info: Dictionary, extension: String = "") -> String:
	for k in export_info:
		if export_info[k] is String:
			pattern = pattern.replace("{%s}" % k, export_info[k])
			pattern = pattern.replace("{%s|to_lower}" % k, export_info[k].to_lower())
			pattern = pattern.replace("{%s|to_upper}" % k, export_info[k].to_upper())
			pattern = pattern.replace("{%s|capitalize}" % k, export_info[k].capitalize())
	if extension:
		pattern = pattern.replace("{extension}", extension)
		pattern = pattern.replace("{extension|to_lower}", extension.to_lower())
		pattern = pattern.replace("{extension|to_upper}", extension.to_upper())
		pattern = pattern.replace("{extension|capitalize}", extension.capitalize())
	return pattern


static func _get_preset_count() -> int:
	return Presets.size()


static func _get_preset_name(preset) -> String:
	match preset:
		Presets.DEFAULT:
			return "Default"
		_:
			return "Unknown"


static func _get_import_options(preset_index: int) -> Array:
	match preset_index:
		Presets.DEFAULT:
			return IMPORT_OPTIONS_DEFAULT
		_:
			return []


static func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return true
