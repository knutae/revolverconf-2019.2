#version 450
in vec2 C;
out vec3 F;
/*layout (location=0)*/ uniform float W;
/*layout (location=1)*/ uniform float H;

// Shader minifier does not (currently) minimize structs, so use short names.
// Using a one-letter name for the struct itself seems to trigger a bug, so use two.
struct ma {
    float A; // ambient
    float D; // diffuse
    float P; // specular
    float S; // shininess
    float R; // reflection
    vec3 C; // HSL color
};

float BOX_SIZE = 0.8;
float DRAW_DISTANCE = 500.0;
float SPHERE_SIZE = 1.5;

float origin_sphere(vec3 p, float radius) {
    return length(p) - radius;
}

float horizontal_plane(vec3 p, float height) {
    return p.y - height;
}

float origin_box(vec3 p, vec3 dimensions, float corner_radius) {
    vec3 a = abs(p);
    return length(max(abs(p) - dimensions, 0.0)) - corner_radius;
}

float infinite_box(vec2 p2, vec2 size) {
    return length(max(abs(p2) - size + vec2(0.05), 0.0)) - 0.05;
}

float infinite_cylinder(vec2 p2, float radius) {
    return length(p2) - radius;
}

float csg_subtraction(float dist1, float dist2) {
    return max(dist1, -dist2);
}

void closest_material(inout float dist, inout ma mat, float new_dist, ma new_mat) {
    if (new_dist < dist) {
        dist = new_dist;
        mat = new_mat;
    }
}

float center_mod(float v, float m) {
    return mod(v - 0.5 * m, m) - 0.5 * m;
}

float center_div(float v, float m) {
    return v - 0.5 * m - center_mod(v, m);
}

const float ONE_SIXTH = 1.0/6.0;
const float ONE_THIRD = 1.0/3.0;
const float TWO_THIRDS = 2.0/3.0;

float tcolor(float tc, float q, float p) {
    if (tc < ONE_SIXTH) {
        return p + 6 * (q - p) * tc;
    } else if (tc < 0.5) {
        return q;
    } else if (tc < TWO_THIRDS) {
        return p + 6 * (q - p) * (TWO_THIRDS - tc);
    } else {
        return p;
    }
}

vec3 hsl_to_rgb(float h, float s, float l) {
    if (s <= 0) {
        // grayscale
        return vec3(l);
    }
    float q;
    if (l < 0.5) {
        q = l * (1 + s);
    } else {
        q = l + s - l * s;
    }
    float p = 2 * l - q;
    float tr = mod(h + ONE_THIRD, 1.0);
    float tg = h;
    float tb = mod(h + TWO_THIRDS, 1.0);
    return vec3(
        tcolor(tr, q, p),
        tcolor(tg, q, p),
        tcolor(tb, q, p));
}

float sin01(float x) {
    return 0.5 + sin(x) * 0.5;
}

ma box_material(vec3 q) {
    vec3 p = vec3(q.x, q.y - BOX_SIZE * 0.5, q.z);
    float xdiv = center_div(p.x, BOX_SIZE) / BOX_SIZE + 5;
    float ydiv = center_div(p.y, BOX_SIZE) / BOX_SIZE + 5;
    float zdiv = center_div(p.z, BOX_SIZE) / BOX_SIZE + 5;
    float hue = sin01(ydiv * 0.15);
    hue += sin01(abs(xdiv) * 0.04);
    hue += sin01(-0.001 * zdiv);
    hue += 0.08 * sin01(xdiv * 11.1 + zdiv * 22.2);
    hue = mod(hue + 0.8, 1.0);
    float saturation = 0.2 + 0.2 * sin01(xdiv * 9.1 + zdiv * 2.1);
    float lightness = 0.5 + 0.5 * sin01(xdiv * 3.3 + zdiv * 8.1);
    vec3 col = vec3(hue, saturation, lightness);
    float reflection = 0.5 / max(1.0, ydiv * 0.5);
    float ambient = 0.1 + 0.8 * sin01(xdiv * 101.11 + zdiv * 121.13) / max(1.0, ydiv * 0.5);
    return ma(ambient, 1.0 - ambient, 0.8, 10.0, reflection, col);
}

float repeated_boxes_xyz(vec3 p, vec3 dimensions, float corner_radius, vec3 modulo) {
    vec3 q = mod(p - 0.5 * modulo, modulo) - 0.5 * modulo;
    return origin_box(q, dimensions, corner_radius);
}

float sky_boxes(vec3 p, vec3 size) {
    float modulo = BOX_SIZE * 10;
    vec3 q = vec3(
        center_mod(p.x, modulo),
        center_mod(p.y - BOX_SIZE * 5, modulo),
        center_mod(p.z, modulo)
    );
    return origin_box(q, size * BOX_SIZE * 0.5 - vec3(0.07), 0.07);
}

float box_landscape(vec3 q) {
    vec3 p = vec3(q.x, q.y - BOX_SIZE * 0.5, q.z);
    float cubes = max(
        repeated_boxes_xyz(p, vec3(BOX_SIZE * 0.42), BOX_SIZE * 0.07, vec3(BOX_SIZE)),
        min(
            horizontal_plane(p, -BOX_SIZE * 0.5),
            min(
                sky_boxes(p, vec3(3,1,3)),
                min(
                    sky_boxes(p, vec3(1,3,3)),
                    sky_boxes(p, vec3(1,1,5))
    ))));
    float valley = csg_subtraction(
        cubes,
        infinite_box(vec2(p.x, p.y + BOX_SIZE), vec2(BOX_SIZE * 2.5, BOX_SIZE * 1.5))
    );
    return valley;
}

float silhouette(vec3 p) {
    p.y += 0.5;
    p.z -= 8;
    return csg_subtraction(
        max(
            min(
                infinite_cylinder(vec2(p.x * 0.8, p.y / 2.3 - 0.05), 0.3),
                min(
                    infinite_cylinder(vec2(p.x, p.y - 0.9), 0.2),
                    origin_box(
                        vec3(p.x, p.y + 0.8, p.z),
                        vec3(0.15, 0.25, 0.2), 0.05))),
            origin_box(p, vec3(1, 2, 0.05), 0.05)),
        min(
            infinite_cylinder(vec2(p.x + 0.6, p.y + 0.48), 0.4),
            infinite_cylinder(vec2(p.x - 0.6, p.y + 0.48), 0.4)));
}

float scene(vec3 p) {
    float dist = origin_sphere(p, SPHERE_SIZE);
    dist = min(dist, silhouette(p));
    dist = min(dist, box_landscape(p));
    return dist;
}

ma scene_material(vec3 p) {
    float dist = origin_sphere(p, SPHERE_SIZE);
    ma mat = ma(0.1, 0.9, 1.5, 6.0, 0.5, vec3(0.15, 0.3, 0.8));
    closest_material(dist, mat, silhouette(p), ma(0.1, 0.9, 1.5, 6.0, 0, vec3(0)));
    closest_material(dist, mat, box_landscape(p), box_material(p));
    return mat;
}

bool ray_march(inout vec3 p, vec3 direction) {
    float total_dist = 0.0;
    for (int i = 0; i < 5000; i++) {
        float dist = scene(p);
        if (dist < 0.001) {
            return true;
        }
        total_dist += dist;
        if (total_dist > DRAW_DISTANCE) {
            return false;
        }
        p += direction * dist;
    }
    return false;
}

vec3 estimate_normal(vec3 p) {
    float epsilon = 0.001;
    return normalize(vec3(
        scene(vec3(p.x + epsilon, p.y, p.z)) - scene(vec3(p.x - epsilon, p.y, p.z)),
        scene(vec3(p.x, p.y + epsilon, p.z)) - scene(vec3(p.x, p.y - epsilon, p.z)),
        scene(vec3(p.x, p.y, p.z + epsilon)) - scene(vec3(p.x, p.y, p.z - epsilon))
    ));
}

vec3 ray_reflection(vec3 direction, vec3 normal) {
    return 2.0 * dot(-direction, normal) * normal + direction;
}

float soft_shadow(vec3 p, vec3 light_direction, float sharpness) {
    p += light_direction * 0.1;
    float total_dist = 0.1;
    float res = 1.0;
    for (int i = 0; i < 20; i++) {
        float dist = scene(p);
        if (dist < 0.01) {
            return 0.0;
        }
        total_dist += dist;
        res = min(res, sharpness * dist / total_dist);
        if (total_dist > DRAW_DISTANCE) {
            break;
        }
        p += light_direction * dist;
    }
    return res;
}

// Background color (RGB, not HSL)
const vec3 background_color = vec3(0.8, 0.9, 1.0);

vec3 apply_fog(vec3 color, float total_distance) {
    return mix(color, background_color, 1.0 - exp(-0.01 * total_distance));
}

vec3 phong_lighting(vec3 p, ma mat, vec3 ray_direction) {
    vec3 normal = estimate_normal(p);
    vec3 light_direction = normalize(vec3(-0.3, -1.0, -0.5));
    float shadow = soft_shadow(p, -light_direction, 20.0);
    float diffuse = max(0.0, mat.D * dot(normal, -light_direction)) * shadow;
    vec3 reflection = ray_reflection(ray_direction, normal);
    float specular = pow(max(0.0, mat.P * dot(reflection, -light_direction)), mat.S) * shadow;
    float lightness = min(mat.C.z * (diffuse + mat.A) + specular, 1.0);
    return hsl_to_rgb(mat.C.x, mat.C.y, lightness);
}

vec3 apply_reflections(vec3 color, ma mat, vec3 p, vec3 direction) {
    float reflection = mat.R;
    for (int i = 0; i < 3; i++) {
        if (reflection <= 0.01) {
            break;
        }
        vec3 reflection_color = background_color;
        direction = ray_reflection(direction, estimate_normal(p));
        vec3 start_pos = p;
        p += 0.05 * direction;
        if (ray_march(p, direction)) {
            reflection_color = phong_lighting(p, scene_material(p), direction);
            reflection_color = apply_fog(reflection_color, length(p - start_pos));
            color = mix(color, reflection_color, reflection);
            mat = scene_material(p);
            reflection *= mat.R;
        } else {
            color = mix(color, reflection_color, reflection);
            break;
        }
    }
    return color;
}

vec3 render(float u, float v) {
    vec3 eye_position = vec3(0, 2, 4);
    vec3 forward = normalize(vec3(0, 0, -3) - eye_position);
    vec3 up = vec3(0.0, 1.0, 0.0);
    vec3 right = normalize(cross(up, forward));
    up = cross(-right, forward);
    float focal_length = 1.0;
    vec3 start_pos = eye_position + forward * focal_length + right * u + up * v;
    vec3 direction = normalize(start_pos - eye_position);
    vec3 p = start_pos;
    vec3 color = background_color;
    if (ray_march(p, direction)) {
        ma mat = scene_material(p);
        color = phong_lighting(p, mat, direction);
        color = apply_reflections(color, mat, p, direction);
        color = apply_fog(color, length(p - start_pos));
    }
    return color;
}

vec3 render_aa(float u, float v) {
    // Antialiasing: render and blend 2x2 points per pixel.
    // That means the distance between points is 1/2 pixel,
    // and the distance from the center (du, dv) is 1/4 pixel.
    // Each pixel size is (2.0 / W, 2.0 / H) since the full area is -1 to 1.
    float du = 2.0 / W / 4.0;
    float dv = 2.0 / H / 4.0;
    vec3 sum =
        render(u - du, v - dv) +
        render(u - du, v + dv) +
        render(u + du, v - dv) +
        render(u + du, v + dv);
    return sum / 4;
}

void main() {
    float u = C.x - 1.0;
    float v = (C.y - 1.0) * H / W;
//#if defined(DEBUG)
    F = render(u, v);
//#else
//    F = render_aa(u, v);
//#endif
    // vignette
    float edge = abs(C.x - 1) + abs(C.y - 1);
    F = mix(F, background_color, min(1, max(0, edge*0.3 - 0.2)));
}
