vec4 applyHue(vec4 color, float hue) {
    // Convert RGB to HSV
    vec3 hsv;
    vec3 rgbColor = color.rgb;
    float cmax = max(max(rgbColor.r, rgbColor.g), rgbColor.b);
    float cmin = min(min(rgbColor.r, rgbColor.g), rgbColor.b);
    float delta = cmax - cmin;

    // Calculate hue
    if (delta == 0.0) {
        hsv.x = 0.0;
    } else if (cmax == rgbColor.r) {
        hsv.x = mod((rgbColor.g - rgbColor.b) / delta, 6.0) / 6.0;
    } else if (cmax == rgbColor.g) {
        hsv.x = ((rgbColor.b - rgbColor.r) / delta + 2.0) / 6.0;
    } else {
        hsv.x = ((rgbColor.r - rgbColor.g) / delta + 4.0) / 6.0;
    }

    // Calculate saturation and value
    hsv.y = (cmax == 0.0) ? 0.0 : (delta / cmax);
    hsv.z = cmax;

    // Adjust hue
    hsv.x = mod(hsv.x + hue, 1.0);

    // Convert back to RGB
    float h = hsv.x * 6.0;
    float c = hsv.z * hsv.y;
    float x = c * (1.0 - abs(mod(h, 2.0) - 1.0));
    float m = hsv.z - c;

    vec3 result;
    if (h < 1.0) {
        result = vec3(c, x, 0.0);
    } else if (h < 2.0) {
        result = vec3(x, c, 0.0);
    } else if (h < 3.0) {
        result = vec3(0.0, c, x);
    } else if (h < 4.0) {
        result = vec3(0.0, x, c);
    } else if (h < 5.0) {
        result = vec3(x, 0.0, c);
    } else {
        result = vec3(c, 0.0, x);
    }

    return vec4(result + m, color.a);
}