// Halftone Configuration
vec4 applyHalftone(vec4 color, sampler2D inputTexture, vec2 texCoord, vec2 texelSize, float scale, float angle) {
    // Convert angle to radians
    float radAngle = angle * 3.14159265 / 180.0;

    // Rotation matrix
    mat2 rotationMatrix = mat2(
        cos(radAngle), -sin(radAngle),
        sin(radAngle), cos(radAngle)
    );

    // Scale and rotate the coordinates
    vec2 rotatedCoord = rotationMatrix * texCoord;
    vec2 scaledCoord = rotatedCoord * scale;

    // Get the cell coordinate
    vec2 cellCoord = floor(scaledCoord);
    vec2 fragCoord = fract(scaledCoord);

    // Sample the original texture at the cell center
    vec2 sampleCoord = (cellCoord + vec2(0.5)) / scale;
    sampleCoord = vec2(
        cos(-radAngle) * sampleCoord.x - sin(-radAngle) * sampleCoord.y,
        sin(-radAngle) * sampleCoord.x + cos(-radAngle) * sampleCoord.y
    );

    vec4 cellColor = texture(inputTexture, sampleCoord);
    float luminance = dot(cellColor.rgb, vec3(0.2989, 0.5870, 0.1140));

    // Calculate distance from center of the cell
    vec2 centerDist = fragCoord - vec2(0.5);
    float dist = length(centerDist);

    // Halftone pattern - circle size based on luminance
    float radius = 0.5 * sqrt(1.0 - luminance);

    if (dist < radius) {
        return vec4(0.0, 0.0, 0.0, cellColor.a);
    } else {
        return vec4(1.0, 1.0, 1.0, cellColor.a);
    }
}