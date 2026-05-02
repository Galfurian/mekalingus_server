shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Take the color from the texture and apply posterization.
    vec4 color = texture(TEXTURE, UV);
    
    // Posterize the color by rounding it to the nearest 1/5th (5 levels of color).
    color.r = round(color.r * 5.0) / 5.0;
    color.g = round(color.g * 5.0) / 5.0;
    color.b = round(color.b * 5.0) / 5.0;
    
    COLOR = color;
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
