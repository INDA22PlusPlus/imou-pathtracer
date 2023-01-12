#ifndef __PRIMITIVES_CL
#define __PRIMITIVES_CL

#define EPSILON 0.1f

#define PRINT_VEC(v) printf("%f %f %f\n", v.x, v.y, v.z)


int euclidean_modulo(int a, int b) {
  int m = a % b;
  if (m < 0) {
    m = (b < 0) ? m - b : m + b;
  }
  return m;
}

bool intersect_sphere(rray *ray, float3* sphere_origin, float sphere_radius, float* t) {

    float3  v = ray->origin-(*sphere_origin);
    float   a = dot(ray->dir, ray->dir);
    float   b = dot(2*v, ray->dir);
    float   c = dot(v,v)-sphere_radius*sphere_radius;

    float   t2;

    float   D = b*b-4*a*c;

    /* No intersection */
    if (D < 0) {
        return false;
    }
    D = sqrt(D);

    /* If the closest intersection is behind the camera, replace it with the
        farthest */
    t2 = ((-b-D)/(2*a) < 0) ? (-b+D)/(2*a) : (-b-D)/(2*a);
    if (t2 <= 0) {
        return false;
    }
    *t = t2;
    return true;
}

bool intersect_plane(rray *ray, float3* plane_normal, float3* point_in_plane, float* t) {
    float       t2;
    float       b;

    b = dot(ray->dir, *plane_normal);
    
    /* No intersection */
    if (b == 0) {
        return false;
    }

    
    t2 = dot(((*point_in_plane)-ray->origin), *plane_normal)/b;
    if (t2 <= 0) {
        return false;
    }
    *t = t2;
    return true;
}


/*  RETURN 0: NO INTERSECTION
    RETURN 1: INTERSECTION SOLID OBJECT
    RETURN 2: INTERSECTION LIGHT OBJECT */
uint findIntersection(rray *ray,
                      __global rsphere* spheres, __global rplane* planes,
                      __global rlight* lights, uchar spheres_num, uchar planes_num,
                      uchar light_num, float3* intersection, 
                      float3* normal, rmaterial* material,
                      read_only image2d_array_t im_arr) {
                        
    rmaterial           transfer_material;

    bool hit_light          = false;
    /* Takes account the intensity */
    float3 light_color;

    bool did_intersect      = false;

    float t                 = INFINITY;
    float3 target_normal;
    float3 interpoint;

    /* Find closest intersection with spheres */
    for (uchar i = 0; i < spheres_num; i++) {
        rsphere sphere = spheres[i];
        float _t;
        bool _intersect = intersect_sphere(ray, &sphere.origin, sphere.radius, &_t);
        if (!_intersect || _t >= t) {
            continue;
        }

        t = _t;
        interpoint = ray->origin+ray->dir*t;
        target_normal = normalize(interpoint-sphere.origin);
        /* To avoid self shadow */
        interpoint += target_normal*EPSILON;

        transfer_material = sphere.material;
        did_intersect = true;
        hit_light = false;
    }

    /* Find closest intersection with planes */
    for (uchar i = 0; i < planes_num; i++) {
        rplane      plane = planes[i];

        float _t;
        bool _intersect = intersect_plane(ray, &plane.normal, &plane.point_in_plane,&_t);
        if (!_intersect || _t >= t) {
            continue;
        }
        
        t = _t;
        interpoint = ray->origin+ray->dir*t;

        target_normal = plane.normal;

        transfer_material = plane.material;

        /* If there's a texture attached on the plane */
        if (plane.material.texture_id >= 0) {
            float3 vecs[3];
            vecs[0] = (float3){1.0f, 0.0f, 0.0f};
            vecs[1] = (float3){0.0f, 1.0f, 0.0f};
            vecs[2] = (float3){0.0f, 0.0f, 1.0f};

            float3 basis[2];

            /* Calculate the basis for the plane */
            for (int i = 0; i < 3; i++) {
                float3 cr = cross(vecs[i], plane.normal);
                if (dot((float3){1.0f,1.0f,1.0f}, cr) == 0.0f) {
                    continue;
                }

                basis[0] = cr;
                basis[1] = cross(plane.normal, cr);
                break;
            }

            float ui = dot(basis[0], interpoint)*plane.material.texture_scale;
            float vi = dot(basis[1], interpoint)*plane.material.texture_scale;

            int2 im_dim = get_image_dim(im_arr);
            
            /* Data used to fetch the pixel from the texture */
            /* euclidean_modulo to guarantee no negative values on coordinates */
            int4 pixel_fetch = (int4){
                euclidean_modulo((int)ui, im_dim[0]),
                euclidean_modulo((int)vi, im_dim[1]),
                plane.material.texture_id, 0 
            };

            int4    pixeli = read_imagei(im_arr, pixel_fetch);
            /* Cast to normalized float manually */
            float3  pixelf = (float3){
                (float)pixeli.x/255.0f,
                (float)pixeli.y/255.0f,
                (float)pixeli.z/255.0f
            };

            transfer_material.rgb = pixelf;
        }

        interpoint += target_normal*EPSILON;

        did_intersect = true;
        hit_light = false;
    }

    /*
    for (uchar i = 0; i < light_num; i++) {
        rlight light = lights[i];

        float _t;
        bool _intersect = intersect_sphere(ray, &light.origin, light.radius, &_t);
        if (!_intersect || _t >= t) {
            continue;
        }

        t = _t;     

        interpoint = ray->origin+ray->dir*t;
        target_normal = normalize(interpoint-light.origin);


        interpoint += target_normal*EPSILON;


        light_color = light.rgb*light.intensity*INVERSE_SQUARE_LIGHT*1/(light.radius*light.radius);
        did_intersect = true;
        hit_light = true;
    }
    */

    if (!did_intersect) { return 0; }

    *intersection   = interpoint;
    *normal         = target_normal;
    *material       = transfer_material;
    if (hit_light) {
        material->transperent   = false;
        material->fresnel       = 0.0f;
        material->ambient       = 1.0f;
        material->specular      = 0.0f;
        material->diffuse       = 0.0f;
        material->shininess     = 0.0f;
        /* High intensity */
        material->rgb           = light_color;
        return 2;
    }
    return 1;
}
#endif