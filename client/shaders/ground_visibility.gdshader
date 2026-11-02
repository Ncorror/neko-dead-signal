shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D sight_mask : filter_linear, repeat_disable;
uniform vec2 map_origin = vec2(-25.0);
uniform vec2 map_size = vec2(50.0);
varying vec2 map_uv;

void vertex() {
    vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    map_uv = (world.xz - map_origin) / map_size;
}

void fragment() {
    vec2 texel = 1.0 / vec2(textureSize(sight_mask, 0));
    float sight = texture(sight_mask, map_uv).r * 0.4;
    sight += texture(sight_mask, map_uv + vec2(texel.x, 0.0)).r * 0.15;
    sight += texture(sight_mask, map_uv - vec2(texel.x, 0.0)).r * 0.15;
    sight += texture(sight_mask, map_uv + vec2(0.0, texel.y)).r * 0.15;
    sight += texture(sight_mask, map_uv - vec2(0.0, texel.y)).r * 0.15;
    ALBEDO = vec3(0.025, 0.05, 0.07);
    ALPHA = 0.96 * (1.0 - sight);
}
