shader_type canvas_item;

// License: CC0
// Author: Ultipuk, https://ultipuk.xyz
// Link: https://godotshaders.com/shader/transition-with-a-pattern-texture/

// Uncomment this if you want to use background texture
//#define USE_BACKGROUND_TEXTURE

// Uncomment this if you want to use closing transition,
// starting removing the pattern after the progress reaches 0.5
//#define USE_CLOSING

// Uncomment this if you want to remove tile distortion.
// The result will look weird in the editor, and the tiles will have some clipping. Intended for viewport-sized canvases.
//#define REMOVE_DISTORTION

/** Actual transition progress. You want to change it from a script. */
uniform float progress: hint_range(0.0, 1.0) = 0.0;
/** The width of the transition as a fraction of the UV. */
uniform float width: hint_range(0.0, 1.0) = 0.5;

/** Actual pattern. You can use a texture with an ALPHA channel.
*   This color is modulated, so you can use modulate parameter to change the color. */
uniform sampler2D tile_texture: source_color, repeat_disable;
/** Tile size in pixels. */
uniform float tile_pixel_size = 32.0;
/** The maximum scale of the tile on the edge of the transition window. */
uniform float tile_grown_scale: hint_range(0.0, 16.0) = 2.0;

/** Transition uses red channel to determine when the part should be visible. */
uniform sampler2D transition_texture;

#ifdef USE_BACKGROUND_TEXTURE
/** Simple background texture that will be mixed with the tile texture. It can be a SubViewport texture or just a gradient. */
uniform sampler2D background_texture: source_color;
#endif

void fragment() {
	vec2 tile_uv = vec2(
		fract(FRAGCOORD.x / tile_pixel_size),
		fract(FRAGCOORD.y / tile_pixel_size)
	);
	
#ifdef REMOVE_DISTORTION
	vec2 tiles = vec2(1.0 / SCREEN_PIXEL_SIZE / tile_pixel_size);
	vec2 transition_uv = ceil(UV * tiles) / tiles;
#else
	vec2 transition_uv = UV;
#endif
	
#ifdef USE_CLOSING
	float part, transition;
	
	if (progress > 0.5) {
		part = (1.0 - (progress - 0.5) * 2.0) * (1.0 + 2.0 * width) - width;
		transition = 1.0 - texture(transition_texture, transition_uv).r;
	} else {
		part = 2.0 * progress * (1.0 + 2.0 * width) - width;
		transition = texture(transition_texture, transition_uv).r;
	}
#else
	float part = progress * (1.0 + 2.0 * width) - width;
	float transition = texture(transition_texture, transition_uv).r;
#endif
	
	float window = max(0.0, min(1.0, width + (part - transition) / width));
	
	tile_uv = tile_uv * 2.0 - 1.0;
	tile_uv /= window * tile_grown_scale;
	tile_uv = (tile_uv + 1.0) * 0.5;
	
#ifdef USE_BACKGROUND_TEXTURE
	vec4 tile = texture(tile_texture, tile_uv) * texture(background_texture, UV);
#else
	vec4 tile = texture(tile_texture, tile_uv);
#endif
	
	COLOR *= tile;
}