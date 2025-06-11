precision mediump float;
uniform sampler2D inputImageTexture;

varying vec2 textureCoordinate;

void main() {
    vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);

    // Define CGA color palette
    vec3 black = vec3(0.0, 0.0, 0.0);
    vec3 blue = vec3(0.0, 0.0, 0.75);
    vec3 green = vec3(0.0, 0.75, 0.0);
    vec3 cyan = vec3(0.0, 0.75, 0.75);
    vec3 red = vec3(0.75, 0.0, 0.0);
    vec3 magenta = vec3(0.75, 0.0, 0.75);
    vec3 yellow = vec3(0.75, 0.75, 0.0);
    vec3 white = vec3(0.75, 0.75, 0.75);

    float brightness = dot(textureColor.rgb, vec3(0.299, 0.587, 0.114));

    // Determine which color to use based on brightness and color components
    vec3 outputColor;

    // Simple approach: quantize based on brightness and RGB dominance
    if (brightness < 0.25) {
        outputColor = black;
    } else if (brightness < 0.5) {
        if (textureColor.r > textureColor.g && textureColor.r > textureColor.b) {
            outputColor = red;
        } else if (textureColor.g > textureColor.r && textureColor.g > textureColor.b) {
            outputColor = green;
        } else {
            outputColor = blue;
        }
    } else if (brightness < 0.75) {
        if (textureColor.r > 0.5 && textureColor.g > 0.5) {
            outputColor = yellow;
        } else if (textureColor.r > 0.5 && textureColor.b > 0.5) {
            outputColor = magenta;
        } else if (textureColor.g > 0.5 && textureColor.b > 0.5) {
            outputColor = cyan;
        } else {
            outputColor = white * 0.8;
        }
    } else {
        outputColor = white;
    }

    gl_FragColor = vec4(outputColor, textureColor.a);
}
