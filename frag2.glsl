#version 410
uniform float time;  // elapsed time in seconds
uniform sampler2D screenTexture;
uniform int blah; // for testing stuff
uniform int n;

in vec3 v_color;
in vec4 v_pos;
in vec2 v_tex_coords;

out vec4 frag_color;

float rand(vec2 co){
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {

    vec4 tex = texture(screenTexture, v_tex_coords);
    vec3 rgb;
    if (blah > 0) {
        float n_ = float(n);
        if (n % 3 == 0) {
            rgb = vec3(1.0, 0.0, 0.0);
        }
        else {
            rgb = vec3(0.0, 0.0, 1.0);
        }

        frag_color = vec4((rgb + ((n_-1.0) * tex.rgb)) / n_, 1.0);
    }

    // If it's the default frame buffer
    else {
        frag_color = tex;
    }
}