#version 410
uniform float time;  // elapsed time in seconds
in vec3 v_color;
in vec4 v_pos;
out vec4 frag_color;

// Returns number from 0 to 1 indicating how "stable" recurrence was.
float stability(vec2 z0, vec2 c, int maxsteps) {
    vec2 zn = z0;
    int step = 0;

    while (step < maxsteps) {
        zn = vec2((zn.x * zn.x) - (zn.y * zn.y), 2 * zn.x * zn.y) + c;
        if (length(zn) > 2) {break;}
        step++;
    }

    return float(step) / float(maxsteps);
}

void main()  {
    // Constants
    float ratio = 1920.0 / 1080.0;

    // TODO: Fix color mapping so it looks like on all levels of zoom.

    // Target coordinate
    vec2 target = vec2(-0.77568377, 0.13646737);

    // Target min/max
    float zoomi = 4.0;  // It's 2 - (-2) = 4.
    float zoomf = 0.000001;
    float xlen = zoomi * pow(zoomf / zoomi, min(1, 20*time / 100.0));
    float ylen = xlen / ratio;

    float xmin = target.x - (xlen/2);
    float xmax = target.x + (xlen/2);
    float ymin = target.y - (ylen/2);
    float ymax = target.y + (ylen/2);

    vec2 mins = vec2(xmin, ymin);
    vec2 maxs = vec2(xmax, ymax);
    vec2 c = v_pos.xy;
    c = ((c + 1) / 2) * (maxs - mins) + mins;

    vec2 z0 = vec2(0.0, 0.0);
    float t = stability(z0, c, int(300));

    // Color Mapping
    vec3 rgb = (vec3(0.3, 0.7, 0.8) * t) + ((1-t) * vec3(0.1, 0.2, 0.3));
    frag_color = vec4(rgb, 1.0);

}