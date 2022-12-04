#version 410
in vec4 a_position;
in vec3 a_color;
in vec2 a_tex_coords;

out vec4 v_pos;
out vec3 v_color;
out vec2 v_tex_coords;
void main()
{
    gl_Position = a_position;
    v_pos = a_position;
    v_color = a_color;
    v_tex_coords = a_tex_coords;
}