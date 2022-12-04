#version 410
#define PI 3.1415926535897932384626433832795028841971
#define INF 100000.0

uniform float time;  // elapsed time in seconds
uniform sampler2D screenTexture;
uniform int blah; // for testing stuff
uniform int n;

in vec3 v_color;
in vec4 v_pos;
in vec2 v_tex_coords;

out vec4 frag_color;

float rho = 50.0;  // dist from world origin to eye
float theta = (-PI / 2.0) + (time * (PI / 10));
float phi = PI / 2.0;
float focus = 40.0;  // must be less than rho!
float s_width = 10.0;  // screen width, in the imaginary world (not actual screen)

// Helper functions
float rng(vec2 co){
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

// Intersection Point
struct IntersectionPoint {
    float t;
    vec3 pos;
    vec3 nor;
    bool on_light;  // true iff point lies on area-light
};

// Ray
struct Ray {
    vec3 origin;
    vec3 dir;
};


// Primitive Shapes
struct Sphere {
    float radius;
    vec3 center;
};

struct Triangle {
    vec3 verts[3];  // Oriented counter-clockwise.
    bool is_light;  // true iff it's an area-light
};

// Scene
struct Scene {
    int n_tris;
    Triangle tris[20];
    int n_spheres;
    Sphere spheres[5];

    // NOTE: INDEX 0 CANNOT BE A LIGHT!
    int t_lights[5];  // list of indices in tris array corresponding to lights
    int s_lights[5];  // list of indices in tris array corresponding to lights

};


// Intersect with triangle
IntersectionPoint intersect_triangle(Triangle tri, Ray ray) {
    // Triangle Data
    vec3 v0 = tri.verts[0];
    vec3 v1 = tri.verts[1];
    vec3 v2 = tri.verts[2];
    vec3 n = normalize(cross(v1 - v0, v2 - v0));

    // Find intersection...
    IntersectionPoint isect;
    isect.t = INF;

    // Triangle parallel with ray
    if (dot(n, ray.dir) == 0.0) {
        return isect;
    }

    float t = dot(n, v0 - ray.origin) / dot(n, ray.dir);
    // Triangle behind the origin
    if (t <= 0.0) {
        return isect;
    }

    // In-out test
    vec3 point = ray.origin + (t * ray.dir);
    bool b0 = dot(cross(v1 - v0, point - v0), n) >= 0.0;
    bool b1 = dot(cross(v2 - v1, point - v1), n) >= 0.0;
    bool b2 = dot(cross(v0 - v2, point - v2), n) >= 0.0;
    if ((b0 && b1) && b2) {
        isect.t = t;
        isect.pos = point;
        isect.nor = n;
    }
    return isect;
}

// Intersect ray with sphere
IntersectionPoint intersect_sphere(Sphere s, Ray ray) {
    // Sphere data
    vec3 center = s.center;
    float radius = s.radius;

    // Find intersection point...
    IntersectionPoint point;
    point.t = INF;

    // Build quadratic
    float A = dot(ray.dir, ray.dir);
    float B = 2.0 * dot(ray.dir, ray.origin - center);
    float C = dot(ray.origin - center, ray.origin - center) - (radius * radius);
    float disc = (B * B) - (4.0 * A * C);

    // Solve quadratic
    if (disc < 0.0) {
        return point;
    }
    float t = min((-B + sqrt(disc)) / (2.0 * A), (-B - sqrt(disc)) / (2.0 * A));
    if (t >= 0.0) {
        point.t = t;
        point.pos = ray.origin + (t * ray.dir);
        point.nor = normalize(point.pos - center);
    }
    return point;
}


// Create Scene 2 — Box with Area Light + 2 Spheres
Scene scene2() {
    Scene scene;

    // Box parameters. It opens up on the negative y-axis. 'h' below stands for 'half'.
    float hx = 30.0 / 2.0;
    float hy = 30.0 / 2.0;
    float hz = 15.0 / 2.0;


    // Box will be a collection of triangles.
    const int n_tris = (5 + 1) * 2;
    scene.n_tris = n_tris;
    const float p = 0.3;  // percentage smaller area-light is compared to ceiling.
    const float dz = -0.1; // z-displacement from ceiling to area light
    Triangle tris[n_tris] = Triangle[n_tris] (
        // Floor
        Triangle(vec3[3]( vec3(-hx, -hy, -hz), vec3(hx, -hy, -hz), vec3(-hx, hy, -hz) ), false),
        Triangle(vec3[3]( vec3(hx, hy, -hz), vec3(-hx, hy, -hz), vec3(hx, -hy, -hz) ), false),
        // Back Wall
        Triangle(vec3[3]( vec3(-hx, hy, -hz), vec3(hx, hy, -hz), vec3(-hx, hy, hz) ), false),
        Triangle(vec3[3]( vec3(hx, hy, hz), vec3(-hx, hy, hz), vec3(hx, hy, -hz) ), false),
        // Left Wall
        Triangle(vec3[3]( vec3(-hx, -hy, -hz), vec3(-hx, hy, -hz), vec3(-hx, -hy, hz) ), false),
        Triangle(vec3[3]( vec3(-hx, hy, hz), vec3(-hx, -hy, hz), vec3(-hx, hy, -hz) ), false),
        // Right Wall
        Triangle(vec3[3]( vec3(hx, -hy, -hz), vec3(hx, hy, -hz), vec3(hx, -hy, hz) ), false),
        Triangle(vec3[3]( vec3(hx, hy, hz), vec3(hx, -hy, hz), vec3(hx, hy, -hz) ), false),
        // Ceiling
        Triangle(vec3[3]( vec3(-hx, -hy, hz), vec3(hx, -hy, hz), vec3(-hx, hy, hz) ), false),
        Triangle(vec3[3]( vec3(hx, hy, hz), vec3(-hx, hy, hz), vec3(hx, -hy, hz) ), false),

        // Area Light
        Triangle(vec3[3]( vec3(-p*hx, -p*hy, hz+dz), vec3(p*hx, -p*hy, hz+dz), vec3(-p*hx, p*hy, hz+dz) ), true),
        Triangle(vec3[3]( vec3(p*hx, p*hy, hz+dz), vec3(-p*hx, p*hy, hz+dz), vec3(p*hx, -p*hy, hz+dz) ), true)

    );
    for (int i=0; i<n_tris; ++i) {
        scene.tris[i] = tris[i];
    }

    // Throw in a couple of spheres too
    const float radius = 4.0;
    const int n_spheres = 2;
    scene.n_spheres = n_spheres;
    Sphere spheres[n_spheres] = Sphere[n_spheres](
        Sphere(radius, vec3(0.4 * hx, -0.2 * hy, -hz + radius)),
        Sphere(radius, vec3(-0.4 * hx, 0.5 * hy, -hz + radius))
    );
    for (int i=0; i<n_spheres; ++i) {
        scene.spheres[i] = spheres[i];
    }

    // Indicate to the scene which primitives are lights (only 2 triangles in this case)
    scene.t_lights[0] = n_tris-1;
    scene.t_lights[1] = n_tris-2;

    return scene;
}


// Generic intersection method of ray with scene
IntersectionPoint intersect_scene(Scene scene, Ray ray) {
    IntersectionPoint minpoint;
    minpoint.t = INF;
    minpoint.on_light = false;

    // Triangle intersection
    for (int i=0; i<scene.n_tris; ++i) {
        IntersectionPoint isect = intersect_triangle(scene.tris[i], ray);
        if (isect.t < minpoint.t) {
            minpoint = isect;
            minpoint.on_light = scene.tris[i].is_light;
        }
    }

    // Sphere intersection
    for (int i=0; i<scene.n_spheres; ++i) {
    IntersectionPoint isect = intersect_sphere(scene.spheres[i], ray);
        if (isect.t < minpoint.t) {
            minpoint = isect;
        }
    }


    return minpoint;
}

void main() {
    vec4 tex = texture(screenTexture, v_tex_coords);
    float n_ = float(n);
    if (blah > 0) {
        // Dynamic constants
        vec2 uv = v_pos.xy;  // In [-1, 1] range! Different from my ShaderToy.
        float AR = 1728.0 / 1051.0;
        float inv_AR = 1.0 / AR;

        // Get camera pos (in range [-1,1]^2) from mouse
        //        vec2 mouseUV = ((iMouse.xy / iResolution.xy) * 2.0) - vec2(1.0);
        //        theta -= mouseUV.x * 2.0;
        //        phi += mouseUV.y * 2.0;

        // Point light (the actual light for Blinn-Phong in this demo)
        vec3 light_pos = 20.0 * vec3(0.0, -1.0, 0.0);
        vec3 light_col = vec3(1.0, 0.0, 0.0);
        vec3 ambient_col = vec3(1.0, 0.0, 0.0);

        // Set eye position and virtual screen dimensions
        vec3 eye = rho * vec3(sin(phi) * cos(theta), sin(phi) * sin(theta), cos(phi));
        float s_height = s_width * inv_AR;

        // Spherical unit vectors
        vec3 theta_hat = vec3(-sin(theta), cos(theta), 0);
        vec3 phi_hat = -vec3(cos(phi) * cos(theta), cos(phi) * sin(theta), -sin(phi));
        vec3 point = (eye * (focus / rho)) + ((uv.x * (s_width / 2.0) * theta_hat) + (uv.y * (s_height / 2.0) * phi_hat));

        // Scene to use
        Scene s = scene2();

        // Single ray (per pixel)
        Ray r;
        r.dir = normalize(point - eye);
        r.origin = eye;

        IntersectionPoint isect = intersect_scene(s, r);
        vec3 rgb = vec3(0.0);
        if (isect.on_light) {
            rgb = vec3(1.0);
        }
        else if (isect.t != INF) {
            vec3 l = normalize(light_pos - isect.pos);
            vec3 v = normalize(-r.dir);
            vec3 h = normalize(l + v);
            vec3 n = isect.nor;

            float ambient = 0.6;
            float diffuse = max(dot(n, l), 0.0);
            float specular = diffuse != 0.0 ? pow(max(dot(n, h), 0.0), 50.0) : diffuse;
            rgb = vec3((0.3 * ambient_col * ambient) + light_col * ((0.6 * diffuse) + (0.3 * specular)));
        }

        // Store possible mouse click
        //        bool moved = (iMouse / iResolution.x).z > 0.0;
        frag_color = vec4(rgb, 1.0);
    }

    // If it's the default frame buffer
    else {
        frag_color = tex;
    }
}