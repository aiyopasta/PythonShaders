#version 410
#define PI 3.141592653589793238462643383279502884197169399375105
#define INF 100000.0

uniform float time;  // elapsed time in seconds
uniform sampler2D screenTexture;
uniform int blah; // for testing stuff
uniform int n;

in vec3 v_color;
in vec4 v_pos;
in vec2 v_tex_coords;

out vec4 frag_color;

float rho = 100.0;  // dist from world origin to eye
float theta = (-PI / 2.0);// + (time * (PI / 10));
float phi = PI / 2.0;
float focus = 80.0;  // must be less than rho!
float s_width = 10.0;  // screen width, in the imaginary world (not actual screen)
int max_bounce = 1;


// Helper functions
float rng(vec2 co){
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

uint wang_hash(inout uint seed)
{
    seed = uint(seed ^ uint(61)) ^ uint(seed >> uint(16));
    seed *= uint(9);
    seed = seed ^ (seed >> 4);
    seed *= uint(0x27d4eb2d);
    seed = seed ^ (seed >> 15);
    return seed;
}

float RandomFloat01(inout uint state)
{
    return float(wang_hash(state)) / 4294967296.0;
}

vec3 RandomUnitVector(inout uint state)
{
    float z = RandomFloat01(state) * 2.0f - 1.0f;
    float a = RandomFloat01(state) * 2.0f * PI;
    float r = sqrt(1.0f - z * z);
    float x = r * cos(a);
    float y = r * sin(a);
    return vec3(x, y, z);
}

vec3 to_world(vec3 dir, vec3 nor) {
    vec3 tan_ = cross(nor, vec3(0.0, 0.0, 1.0));
    vec3 bitan = cross(tan_, nor);
    mat3 frame = mat3(bitan, tan_, nor);
    return frame * dir;
}

// Material
struct Material {
    vec3 diffuseCol;  // Each entry must be between 0 and 1 if non-light. Else, this is Le.
    vec3 specularCol;
    float shine;
    float percentSpecular;
    bool is_light;
};

// Intersection Point
struct IntersectionPoint {
    float t;
    vec3 pos;
    vec3 nor;
    Material mat;
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
    Material mat;
};

struct Triangle {
    vec3 verts[3];  // Oriented counter-clockwise.
    bool is_light;  // true iff it's an area-light
    Material mat;
};

// Scene
struct Scene {
    int n_tris;
    Triangle tris[20];
    int n_spheres;
    Sphere spheres[5];

    // NOTE: INDEX 0 CANNOT BE A LIGHT!
    // Assumption: Only pairs of triangles forming a rectangle can be a light.
    ivec2 t_lights[5];  // list of pairs of indices corresponding to lights in tris array

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
        isect.mat = tri.mat;
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
    float t1 = (-B + sqrt(disc)) / (2.0 * A);
    float t2 = (-B - sqrt(disc)) / (2.0 * A);
    float t = 0.0 < min(t1, t2) ? min(t1, t2) : max(max(t1, 0.0), max(t2, 0.0));
    if (t > 0.0) {
        point.t = t;
        point.pos = ray.origin + (t * ray.dir);
        point.nor = normalize(point.pos - center);
        point.mat = s.mat;
    }
    return point;
}


// Create Scene 2 — Box with Area Light + 2 Spheres
Scene scene2() {
    Scene scene;

    // Color / light params
    vec3 Le = vec3(6.0);

    // Create Materials
    Material redDiffuse = Material(vec3(1.0, 0.0, 0.0), vec3(0.0), 0.0, 0.0, false);
    Material greenDiffuse = Material(vec3(0.0, 1.0, 0.0), vec3(0.0), 0.0, 0.0, false);
    Material blueDiffuse = Material(vec3(0.0, 0.0, 1.0), vec3(0.0), 0.0, 0.0, false);
    Material whiteDiffuse = Material(vec3(1.0), vec3(0.0), 0.0, 0.0, false);
    Material whiteLight = Material(Le, vec3(0.0), 0.0, 0.0, true);
    Material specular = Material(vec3(0.0), vec3(1.0), 1.0, 1.0, false);

    Material blueGloss = Material(vec3(0.0, 0.0, 1.0), vec3(0.0, 0.4, 0.4), 0.0, 0.5, false);

    // Box parameters. It opens up on the negative y-axis. 'h' below stands for 'half'.
    float hx = 30.0 / 2.0;
    float hy = 30.0 / 2.0;
    float hz = 15.0 / 2.0;


    // Box will be a collection of triangles.
    // Triangle(vec3[3]( vec3(-hx, hy, -hz), vec3(hx, hy, -hz), vec3(-hx, hy, hz) ))
    const int n_tris = 2;//(5 + 1) * 2;
    scene.n_tris = n_tris;
    const float p = 0.3;  // percentage smaller area-light is compared to ceiling.
    const float dz = -0.1; // z-displacement from ceiling to area light
    Triangle tris[n_tris] = Triangle[n_tris](
        // Floor
//        Triangle(vec3[3]( vec3(-hx, -hy, -hz), vec3(hx, -hy, -hz), vec3(-hx, hy, -hz) ),
//                 false,
//                 whiteDiffuse),
//        Triangle(vec3[3]( vec3(hx, hy, -hz), vec3(-hx, hy, -hz), vec3(hx, -hy, -hz) ),
//                 false,
//                 whiteDiffuse),
//        // Back Wall
//        Triangle(vec3[3]( vec3(-hx, hy, -hz), vec3(hx, hy, -hz), vec3(-hx, hy, hz) ),
//                 false,
//                 whiteDiffuse),
//        Triangle(vec3[3]( vec3(hx, hy, hz), vec3(-hx, hy, hz), vec3(hx, hy, -hz) ),
//                 false,
//                 whiteDiffuse),
//        // Left Wall
//        Triangle(vec3[3]( vec3(-hx, -hy, -hz), vec3(-hx, hy, -hz), vec3(-hx, -hy, hz) ),
//                 false,
//                 redDiffuse),
//        Triangle(vec3[3]( vec3(-hx, hy, hz), vec3(-hx, -hy, hz), vec3(-hx, hy, -hz) ),
//                 false,
//                 redDiffuse),
//        // Right Wall
//        Triangle(vec3[3]( vec3(hx, -hy, -hz), vec3(hx, -hy, hz), vec3(hx, hy, -hz) ),
//                 false,
//                 greenDiffuse),
//        Triangle(vec3[3]( vec3(hx, hy, hz), vec3(hx, hy, -hz), vec3(hx, -hy, hz) ),
//                 false,
//                 greenDiffuse),
//        // Ceiling
//        Triangle(vec3[3]( vec3(-hx, -hy, hz), vec3(-hx, hy, hz), vec3(hx, -hy, hz) ),
//                 false,
//                 whiteDiffuse),
//        Triangle(vec3[3]( vec3(hx, hy, hz), vec3(hx, -hy, hz), vec3(-hx, hy, hz) ),
//                 false,
//                 whiteDiffuse),

        // Area Light
        Triangle(vec3[3]( vec3(-p*hx, -p*hy, hz+dz), vec3(-p*hx, p*hy, hz+dz), vec3(p*hx, -p*hy, hz+dz) ),
                 true,
                 whiteLight),
        Triangle(vec3[3]( vec3(p*hx, p*hy, hz+dz), vec3(p*hx, -p*hy, hz+dz), vec3(-p*hx, p*hy, hz+dz) ),
                 true,
                 whiteLight)

    );
    for (int i=0; i<n_tris; ++i) {
        scene.tris[i] = tris[i];
    }

    // Throw in a couple of spheres too
    const float radius = 4.0;
    const int n_spheres = 1;//2;
    scene.n_spheres = n_spheres;
    Sphere spheres[n_spheres] = Sphere[n_spheres](
        Sphere(radius, vec3(0.4 * hx, -0.2 * hy, -hz + radius), whiteDiffuse/*specular*/)
        //Sphere(radius, vec3(-0.4 * hx, 0.5 * hy, -hz + radius), blueGloss)
    );
    for (int i=0; i<n_spheres; ++i) {
        scene.spheres[i] = spheres[i];
    }

    // Indicate to the scene which primitives are lights (only 2 triangles in this case)
    scene.t_lights[0] = ivec2(n_tris-1, n_tris-2);
    return scene;
}


// Generic intersection method of ray with scene
IntersectionPoint intersect_scene(Scene scene, Ray ray) {
    IntersectionPoint minpoint;
    minpoint.t = INF;

    // Triangle intersection
    for (int i=0; i<scene.n_tris; ++i) {
        IntersectionPoint isect = intersect_triangle(scene.tris[i], ray);
        if (isect.t < minpoint.t) {
            minpoint = isect;
            minpoint.mat = scene.tris[i].mat;
        }
    }

    // Sphere intersection
    for (int i=0; i<scene.n_spheres; ++i) {
    IntersectionPoint isect = intersect_sphere(scene.spheres[i], ray);
        if (isect.t < minpoint.t) {
            minpoint = isect;
            minpoint.mat = scene.spheres[i].mat;
        }
    }


    return minpoint;
}

void main() {
    vec4 tex = texture(screenTexture, v_tex_coords);
    float n_ = float(n);
    if (blah > 0) {
        // Dynamic constants
        vec2 uv = v_pos.xy;  // In [-1, 1] range, different from my ShaderToy!
        float AR = gl_FragCoord.x / gl_FragCoord.y;
        float inv_AR = 1.0 / AR;
        uint rngState = uint(uint(uv.x) * uint(1973) + uint(uv.y) * uint(9277) + uint(n) * uint(26699)) | uint(1);
        bool prevHitWasSpecular = false;

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

        // Primary ray (per pixel, without jittering)
        Ray r;
        r.dir = normalize(point - eye);
        r.origin = eye;

        vec3 radiance = vec3(0.0);
        vec3 throughput = vec3(1.0);
        int bounce = 0;
        int m_bounce = max_bounce; //(iMouse / iResolution.x).z > 0.0 ? 1 : max_bounce;
        while (bounce <= m_bounce) {
            IntersectionPoint isect = intersect_scene(s, r);
            Material mat = isect.mat;
            // If intersected, only then continue loop
            if (isect.t != INF) {
                // If we hit a light
                if (mat.is_light) {
                    vec3 Le = mat.diffuseCol;
                    if (bounce == 0 || prevHitWasSpecular) {radiance += throughput * Le;}
                    break;  // End loop if we hit light (either including it's brightess or not)
                }

                // Otherwise we hit a legit object.
                vec3 albedo = mat.diffuseCol;
                vec3 specularCol = mat.specularCol;
                bool specular = mat.percentSpecular > 0.0;
                // 1. Directly sample the light sources for point. NOTE: Currently only implemented for 1 source.
                Triangle light_half = s.tris[s.t_lights[0].x];
                vec2 xi = vec2(RandomFloat01(rngState), RandomFloat01(rngState));
                vec3 basis1 = light_half.verts[1] - light_half.verts[0];
                vec3 basis2 = light_half.verts[2] - light_half.verts[0];
                vec3 light_point = light_half.verts[0] + (xi.x * basis1) + (xi.y * basis2);
                // 2. Cast shadow ray.
                vec3 shadow_dir = normalize(light_point - isect.pos);
                vec3 shadow_origin = isect.pos + (0.01 * shadow_dir);  // prevent shadow acne
                Ray shadow_ray = Ray(shadow_origin, shadow_dir);
                IntersectionPoint shadow_isect = intersect_scene(s, shadow_ray);

                // 3. If not in shadow AND material isn't a mirror, add to the radiance.
                if (length(shadow_isect.pos - light_point) < 0.001) {
                    float dist = length(shadow_isect.pos - isect.pos);
                    float pdf_A = 1.0 / length(cross(basis1, basis2));
                    float cosine_prime = dot(shadow_isect.nor, -shadow_dir);
                    float pdf_omega = pdf_A * (dist * dist) / cosine_prime;
                    vec3 f = specular ? vec3(0.0) : (albedo / PI);  // Whichever output direction we sample, f term will be 0 if perfect mirror.
                    // Make sure we're coming from the correct side of the area light.
                    if (cosine_prime >= 0.0) {
                        vec3 Le = shadow_isect.mat.diffuseCol;
                        radiance += Le * f * abs(dot(isect.nor, shadow_dir)) * throughput / pdf_omega;
                    }
                }

                // 4. Sample new ray direction according to BRDF function, and it's pdf.
                vec3 omega_o = normalize(isect.nor + RandomUnitVector(rngState));
                float pdf_brdf = cos(dot(isect.nor, omega_o)) / PI;
                bool coin = RandomFloat01(rngState) < mat.percentSpecular;
                if (coin) {
                    omega_o = r.dir - (2.0 * dot(isect.nor, r.dir)) * isect.nor;
                    pdf_brdf = 1.0;  // It's actually a delta distribution but it cancels out so pdf has no contribution.
                }
                r.origin = isect.pos + (0.01 * omega_o);
                r.dir = omega_o;

                // 5. Update throughput value
                vec3 f = coin ? vec3(mat.specularCol / cos(dot(isect.nor, -r.dir))) : albedo / PI;  // Here, specular gives legit value as we're ONLY sampling in the one possible direction.
                float coin_pdf = coin ? mat.percentSpecular : 1.0 - mat.percentSpecular;
                throughput *= f * abs(dot(isect.nor, r.dir)) / pdf_brdf / coin_pdf;

                // 6. Terminate via Russian Roullete
                if (bounce > 3) {
                    float q = max(throughput.r, max(throughput.g, throughput.b));
                    if (RandomFloat01(rngState) > q) {
                        break;
                    }

                    throughput /= q;
                }

                // 7. Store whether this, now-previous-hit, was specular.
                prevHitWasSpecular = coin;


                bounce += 1;
            }

            else {
                break;  // Nothing was hit.
            }

        }

        // Gamma Correct
        radiance = pow(radiance, vec3(1.0/2.2));

        // Store possible mouse click
//        bool moved = (iMouse / iResolution.x).z > 0.0;

        // Average over last frames
//        vec3 lastRGB = texture(iChannel0, uv).xyz;
//        float prev_alpha = texture(iChannel0, uv).a;
//        float alpha = (prev_alpha == 0.0 || moved) ? 1.0 : prev_alpha / (prev_alpha + 1.0);
//        vec3 rgb = mix(lastRGB, radiance, alpha);
        frag_color = vec4(vec3(radiance + ((n_ - 1) * tex.rgb)) / n_, 1.0);
    }

    // If it's the default frame buffer
    else {
        frag_color = tex;
    }
}