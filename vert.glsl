#version 410
in vec4 a_position;
in vec3 a_color;

out vec3 v_color;
out vec4 v_pos;
void main()
{
    gl_Position = a_position;
    v_color = a_color;
    v_pos = a_position;
}