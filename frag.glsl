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
//
//float pan(float amt, float t) {
//    return min(amt, t) / amt;
//}

float zoom(float amt, float t) {
    return min(1.0, t / amt);
}

void main()  {
    // Constants
    float ratio = 1920.0 / 1080.0;

    // Target coordinate
    vec2 target = vec2(-0.5, 0.0);//vec2(-0.77568377, 0.13646737);

    // Target min/max
    float amt = 2;
    float zoomi = 4.0;
    float zoomf = 4.0;//0.00001;
    float xlen = zoomi * pow(zoomf / zoomi, min(1, 20*time / 100.0));
    float ylen = xlen / ratio;

    float xmin_target = target.x - (xlen/2);
    float xmax_target = target.x + (xlen/2);
    float ymin_target = target.y - (ylen/2);
    float ymax_target = target.y + (ylen/2);

    float xmin = xmin_target;//((-xlen/2) * (1 - pan(2, time))) + (time * xmin_target);
    float xmax = xmax_target;//((xlen/2) * (1 - pan(2, time))) + (time * xmax_target);;
    float ymin = ymin_target;//((-xlen/2) * (1 - pan(2, time))) + (time * xmin_target);
    float ymax = ymax_target;//((xlen/2) * (1 - pan(2, time))) + (time * xmax_target);;

    vec2 mins = vec2(xmin, ymin);
    vec2 maxs = vec2(xmax, ymax);
    vec2 c = v_pos.xy;
    c = ((c + 1) / 2) * (maxs - mins) + mins;

    vec2 z0 = vec2(0.0, 0.0);
    float t = stability(z0, c, int(30));

    // Color Mapping
    vec3 rgb = (vec3(0.3, 0.7, 0.8) * t) + ((1-t) * vec3(0.1, 0.2, 0.3));
    frag_color = vec4(rgb, 1.0);

}