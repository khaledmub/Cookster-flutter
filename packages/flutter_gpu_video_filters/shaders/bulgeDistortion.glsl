precision mediump float;
uniform sampler2D inputImageTexture;
uniform float inputRadius;
uniform float inputScale;
uniform vec2 inputCenter;

varying vec2 textureCoordinate;

void main() {
    vec2 center = inputCenter;
    float radius = inputRadius;
    float scale = inputScale;

    vec2 textureCoordinateToUse = textureCoordinate;
    vec2 normCoord = 2.0 * textureCoordinate - 1.0;
    float r = length(normCoord);

    if (r < radius) {
        // Apply the bulge effect within the radius
        float percent = 1.0 - ((radius - r) / radius) * scale;
        percent = clamp(percent, 0.0, 1.0);

        // Calculate the distorted coordinate
        normCoord *= percent;
        textureCoordinateToUse = (normCoord + 1.0) * 0.5;
    }

    gl_FragColor = texture2D(inputImageTexture, textureCoordinateToUse);
}