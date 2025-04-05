shader_type canvas_item;

uniform float time_of_day : hint_range(0.0, 1.0) = 0.0;

vec3 blend_shades(float t) {
    vec3 midnight  = vec3(0.01, 0.01, 0.02); // Very dark blue
    vec3 pre_dawn  = vec3(0.15, 0.1, 0.2);  // Faint purple hint
    vec3 dawn      = vec3(1.0, 0.4, 0.3);    // Warm reddish-orange
    vec3 midday    = vec3(1.0, 1.0, 1.0);    // Neutral daylight
    vec3 dusk      = vec3(0.8, 0.5, 0.6);    // Pink-purple sunset
    vec3 evening   = vec3(0.15, 0.1, 0.2);   // Cool muted purple
    if (t < 0.15) {
        return mix(midnight, pre_dawn, t / 0.15);
    } else if (t < 0.25) {
        return mix(pre_dawn, dawn, (t - 0.15) / 0.1);
    } else if (t < 0.5) {
        return mix(dawn, midday, (t - 0.25) / 0.25);
    } else if (t < 0.75) {
        return mix(midday, dusk, (t - 0.5) / 0.25);
    } else if (t < 0.9) {
        return mix(dusk, evening, (t - 0.75) / 0.15);
    } else {
        return mix(evening, midnight, (t - 0.9) / 0.1);
    }
}


vec3 hsl2rgb(vec3 hsl) {
    float h = hsl.x;
    float s = hsl.y;
    float l = hsl.z;

    float c = (1.0 - abs(2.0 * l - 1.0)) * s;
    float x = c * (1.0 - abs(mod(h * 6.0, 2.0) - 1.0));
    float m = l - 0.5 * c;

    vec3 rgb;

    if (h < 1.0 / 6.0) rgb = vec3(c, x, 0.0);
    else if (h < 2.0 / 6.0) rgb = vec3(x, c, 0.0);
    else if (h < 3.0 / 6.0) rgb = vec3(0.0, c, x);
    else if (h < 4.0 / 6.0) rgb = vec3(0.0, x, c);
    else if (h < 5.0 / 6.0) rgb = vec3(x, 0.0, c);
    else rgb = vec3(c, 0.0, x);

    return rgb + vec3(m);
}

uniform float sunrise_start : hint_range(0.0, 1.0) = 0.20; // Dawn starts
uniform float sunrise_end   : hint_range(0.0, 1.0) = 0.30; // Fully daylight
uniform float sunset_start  : hint_range(0.0, 1.0) = 0.70; // Sun begins setting
uniform float sunset_end    : hint_range(0.0, 1.0) = 0.80; // Night begins

void fragment() {
    float brightness;
    // Calculate the brightness based on the time of day.
    if (time_of_day < sunrise_start || time_of_day > sunset_end) {
        brightness = 0.01;
    } else if (time_of_day < sunrise_end) {
        brightness = mix(0.01, 1.0, clamp((time_of_day - sunrise_start) / (sunrise_end - sunrise_start), 0.0, 1.0));
    } else if (time_of_day < sunset_start) {
        brightness = 1.0;
    } else {
        brightness = mix(0.01, 1.0, clamp((sunset_end - time_of_day) / (sunset_end - sunset_start), 0.0, 1.0));
    }
    vec3 tint   = blend_shades(time_of_day);
    float alpha = mix(0.6, 0.0, brightness);
    COLOR = vec4(tint * brightness, alpha);
}
