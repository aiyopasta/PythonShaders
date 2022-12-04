#version 410
uniform float time;  // elapsed time in seconds
uniform sampler2D screenTexture;
uniform int blah; // for testing stuff
in vec3 v_color;
in vec4 v_pos;
in vec2 v_tex_coords;

out vec4 frag_color;
void main() {

    vec4 tex = texture(screenTexture, v_tex_coords);
    vec3 rgb;
    if (blah == 1.0) {
        rgb = vec3(1.0, 0.0, 0.0) + tex.rgb;
        frag_color = vec4(rgb, 1.0);
    } else if (blah == 2.0) {
        rgb = vec3(0.0, 1.0, 0.0) + tex.rgb;
        frag_color = vec4(rgb, 1.0);
    }
    else {
        frag_color = tex;
    }








//    vec2 tex_coords = gl_FragCoord.xy / vec2(1920.0, 1080.0);
////    frag_color = vec4(0.0023)
//
//    vec3 rgb;
//    if (tex_coords.x < 1.0) {
//        rgb = vec3(0.001, 0.0, 0.0);
//    }
//    else {
//        rgb = vec3(0.0, 0.001, 0.0);
//    }
//    frag_color = vec4(rgb, 1.0) + texture(prev_col, tex_coords);
}