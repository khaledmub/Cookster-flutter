precision mediump float;
uniform sampler2D inputImageTexture;
uniform float inputContrast;

varying vec2 textureCoordinate;

void main() {
    vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
    gl_FragColor = vec4(((textureColor.rgb - vec3(0.5)) * inputContrast + vec3(0.5)), textureColor.a);
}