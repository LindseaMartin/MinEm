extends RefCounted
## Character customisation: colour choices, hats and the recolour shader.
## The shader swaps the exact palette colours of Art/character.png, so it
## keeps working with that sheet. If the sprite art changes, update the
## SRC_* colours below to match the new palette.

const HAIR := ["6a4834", "2b2422", "d9b054", "b5552b", "9a9a9a", "e8e4dc", "3b6bc4", "d86ba8", "4fa35a"]
const SKIN := ["e8d4b2", "f3d9c4", "d9a877", "b07a4f", "8a5a3b", "5e3b28"]
const SHIRT := ["c43c3c", "3c6ec4", "3e9b55", "d9a42e", "7a4db3", "4a4a52", "e8e4dc", "d06a2e"]
const PANTS := ["65659b", "4a3a2a", "2e2e36", "6e7a4a", "3d5a8a", "8a6a4a"]

## Hats are drawn in code (Characters/hat.gd). "unlock" is a milestone id
## from Game.MILESTONES, or "" if it is available from the start.
const HATS := [
	{"id": "none", "name": "No hat", "unlock": ""},
	{"id": "helmet", "name": "Miner's helmet", "unlock": ""},
	{"id": "cap", "name": "Flat cap", "unlock": ""},
	{"id": "bandana", "name": "Bandana", "unlock": ""},
	{"id": "flower", "name": "Lucky flower", "unlock": "gleam1"},
	{"id": "tophat", "name": "Top hat", "unlock": "earn1k"},
	{"id": "skull", "name": "Fossil helm", "unlock": "depth3"},
	{"id": "crown", "name": "Crystal crown", "unlock": "sets"},
]

## The default look lives in Game.reset() (kept there to avoid a script cycle).

const SHADER := """
shader_type canvas_item;

uniform vec3 hair : source_color = vec3(0.416, 0.282, 0.204);
uniform vec3 skin : source_color = vec3(0.910, 0.831, 0.698);
uniform vec3 shirt : source_color = vec3(0.769, 0.235, 0.235);
uniform vec3 pants : source_color = vec3(0.396, 0.396, 0.608);
uniform float vframes = 8.0;

bool is_col(vec3 c, vec3 ref) {
	return distance(c, ref / 255.0) < 0.03;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 col = c.rgb;
	// Only the top of each frame is hair; the same dark brown is used for boots.
	bool head = fract(UV.y * vframes) < 0.55;
	if (is_col(col, vec3(106.0, 72.0, 52.0))) col = hair;
	else if (head && is_col(col, vec3(67.0, 46.0, 39.0))) col = hair * 0.63;
	else if (is_col(col, vec3(232.0, 212.0, 178.0))) col = skin;
	else if (is_col(col, vec3(191.0, 167.0, 135.0))) col = skin * 0.82;
	else if (is_col(col, vec3(196.0, 60.0, 60.0))) col = shirt;
	else if (is_col(col, vec3(136.0, 46.0, 46.0))) col = shirt * 0.69;
	else if (is_col(col, vec3(104.0, 28.0, 28.0))) col = shirt * 0.5;
	else if (is_col(col, vec3(101.0, 101.0, 155.0))) col = pants;
	else if (is_col(col, vec3(85.0, 134.0, 185.0))) col = min(pants * 1.25, vec3(1.0));
	COLOR = vec4(col, c.a);
}
"""


static func pick(list: Array, index: int) -> Color:
	return Color(str(list[clampi(index, 0, list.size() - 1)]))


static func make_material(look: Dictionary) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = shader
	update_material(m, look)
	return m


static func update_material(m: ShaderMaterial, look: Dictionary) -> void:
	var c := pick(HAIR, int(look.get("hair", 0)))
	m.set_shader_parameter("hair", Vector3(c.r, c.g, c.b))
	c = pick(SKIN, int(look.get("skin", 0)))
	m.set_shader_parameter("skin", Vector3(c.r, c.g, c.b))
	c = pick(SHIRT, int(look.get("shirt", 0)))
	m.set_shader_parameter("shirt", Vector3(c.r, c.g, c.b))
	c = pick(PANTS, int(look.get("pants", 0)))
	m.set_shader_parameter("pants", Vector3(c.r, c.g, c.b))


static func hat_unlocked(hat: Dictionary) -> bool:
	return str(hat["unlock"]) == "" or Game.milestones_done.has(hat["unlock"])


static func unlock_hint(hat: Dictionary) -> String:
	for m in Game.MILESTONES:
		if m["id"] == hat["unlock"]:
			return "%s: %s" % [m["name"], m["desc"]]
	return ""
