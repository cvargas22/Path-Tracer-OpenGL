#version 430 core

layout(local_size_x = 8, local_size_y = 8) in;

layout(binding = 0, rgba32f) uniform image2D color;

layout(binding=2) uniform CAM_BUF

{

    mat4 IVP;

    vec4 eye;

    vec4 nfwh;

    vec4 seed;

};

layout(binding=4) uniform LUZPOS_BUF{

    vec3 luzpos;
};

layout(binding=5) uniform ON_BUF

{

    int on;
};

layout(binding=6) uniform LOC_BUF

{

    vec3 pos1;
    vec3 pos2;
    vec3 pos3;
    vec3 pos4;
    vec3 pos5;

};

layout(binding=7) uniform CAL_BUF
{
    int calidad;
};

#define EYE eye.xyz

#define NEAR nfwh.x

#define FAR nfwh.y

#define WIDTH nfwh.z

#define HEIGHT nfwh.w

#define SAMPLES seed.w

#define CBOUNCES 6

#define CSAMPLES 45

struct Material{

    vec4 reflectance, emittance;

};

layout(binding=3) buffer SDF_BUF{   

    Material materials[18];

};

#define ROUGHNESS(i) materials[(i)].emittance.w

vec3 toWorld(float x, float y, float z){

    vec4 t = vec4(x, y, z, 1.0);

    t = IVP * t;

    return vec3(t/t.w);

}

struct MapSample{

    float distance;

    int matid;

};

float rand( inout uint f) {

    f = (f ^ 61) ^ (f >> 16);

    f *= 9;

    f = f ^ (f >> 4);

    f *= 0x27d4eb2d;

    f = f ^ (f >> 15);

    return fract(float(f) * 2.3283064e-10) * 2.0 - 1.0;

}

float randUni(inout uint f){

    f = (f ^ 61) ^ (f >> 16);

    f *= 9;

    f = f ^ (f >> 4);

    f *= 0x27d4eb2d;

    f = f ^ (f >> 15);

    return fract(float(f) * 2.3283064e-10);

}

vec3 uniHemi(vec3 N, inout uint s){

    vec3 dir;

    float len;

    int i = 0;

    do{

        dir = vec3(rand(s), rand(s), rand(s));

        len = length(dir);

    }while(len > 1.0 && i < 5);

    

    if(dot(dir, N) < 0.0)

        dir *= -1.0;

    

    return dir / len;

}

vec3 cosHemi(vec3 N, inout uint s){

    // derived from smallpt

    

    float r1 = 3.141592 * 2.0 * randUni(s);

    float r2 = randUni(s);

    float r2s = sqrt(r2);

    

    vec3 u;

    if(abs(N.x) > 0.1)

        u = cross(vec3(0.0, 1.0, 0.0), N);

    else

        u = cross(vec3(1.0, 0.0, 0.0), N);

    

    u = normalize(u);

    vec3 v = cross(N, u);

    return normalize(

        u * cos(r1) * r2s 

        + v * sin(r1) * r2s 

        + N * sqrt(1.0 - r2)

        );

}

float vmax(vec3 a){

    return max(max(a.x, a.y), a.z);

}

//Esfera reemplazando funcion length() por distance() anteriormente usada
MapSample sphere(vec3 ray, vec3 location, float radius, int mat){

    vec3 p = ray - location;

    return MapSample(length(p) - radius, mat);

}



MapSample box(vec3 ray, vec3 location, vec3 dimension, int mat){

    vec3 d = abs(ray - location) - dimension;

    return MapSample(vmax(d), mat);

}


MapSample plane(vec3 ray, vec3 location, vec3 normal, int mat){

    return MapSample(dot(ray - location, normal), mat);

}

MapSample join(MapSample a, MapSample b){

    if(a.distance <= b.distance)

        return a;

    return b;

}

float diff(MapSample a, MapSample b){

    return a.distance - b.distance;

}

vec3 tri(vec3 r, float d){

    return vec3(

        modf(r.x, d),

        modf(r.y, d),

        modf(r.z, d)

    );

}

/*

 0: white

 1: mirror

 2: blue

 3: red

 4: light

*/

MapSample map(vec3 ray){


        MapSample a = sphere(ray, // chrome spheres

        pos1,

        1.0f,

        8);

        /*MapSample a = cylinderCap(ray,

         vec3(0.0f, 2.0f, 0.0f),

         vec2(0.3f,1.0f),

         8);*/
        

        a = join(a, sphere(ray, // chrome spheres

        vec3(-5.0f, 0.0f, 0.0f),

        1.0f,

        7));
        a = join(a, sphere(ray, // chrome spheres

        vec3(5.0f, 0.0f, 0.0f),

        1.0f,

        6));

        a = join(a, sphere(ray, // chrome spheres

        vec3(0.0f, 0.0f, -5.0f),

        1.0f,

        5));

        a = join(a, sphere(ray, // chrome spheres

        vec3(1.0f, 0.0f, 0.0f),

        1.0f,

        4));

        if(on == 0){
        a = join(a, plane(ray, // left wall

        vec3(-7.0f, 0.0f, 0.0f),

        vec3(1.0f, 0.0f, 0.0f),

        9));

        a = join(a, plane(ray, // right wall

        vec3(7.0f, 0.0f, 0.0f),

        vec3(-1.0f, 0.0f, 0.0f),

        10));

        a = join(a, plane(ray, // ceiling

        vec3(0.0f, 7.0f, 0.0f),

        vec3(0.0f, -1.0f, 0.0f),

        11));

         a = join(a, plane(ray, // floor

        vec3(0.0f, -7.0f, 0.0f),

        vec3(0.0f, 1.0f, 0.0f),

        12));

       

        a = join(a, plane(ray, // back

        vec3(0.0f, 0.0f, -7.0f),

        vec3(0.0f, 0.0f, 1.0f),

        13));

        a = join(a, plane(ray, // front

        vec3(0.0f, 0.0f, 11.0f),

        vec3(0.0f, 0.0f, -1.0f),

        14));
        }


        /* CAJA

        a = join(a, box(ray,    // light

        vec3(0.0f, 4.75f, 0.0f),

        vec3(2.0f, .1f, 4.0f),

        0));

        */
        

        a = join(a, sphere(ray, // light

        //vec3(0.0f, 0.0f, 0.0f),

        luzpos,

        1.0f,

        0));

        
        return a;
    
        

}

vec3 map_normal(vec3 point){

    vec3 e = vec3(0.0001, 0.0, 0.0);

    return normalize(vec3(

        diff(map(point + e.xyz), map(point - e.xyz)),

        diff(map(point + e.zxy), map(point - e.zxy)),

        diff(map(point + e.zyx), map(point - e.zyx))

    ));

}

vec3 roughBlend(vec3 newdir, vec3 oldir, vec3 N, int matid){

    return normalize(

        mix(

            normalize(

                reflect(oldir, N)), 

            newdir, 

            ROUGHNESS(matid)

            )

        );

}

float absum(vec3 a){

    return abs(a.x) + abs(a.y) + abs(a.z);

}

vec3 trace(vec3 rd, vec3 eye, inout uint s){

    float e = 0.001;

    vec3 col = vec3(0.0, 0.0, 0.0);

    vec3 mask = vec3(1.0, 1.0, 1.0);

    

    for(int i = 0; i < CBOUNCES; i++){    // bounces

        MapSample sam;
        for(int j = 0; j < CSAMPLES; j++){ // steps

            sam = map(eye);

            if(abs(sam.distance) < e){

                break;

            }

            eye = eye + rd * sam.distance;

        }

        vec3 N = map_normal(eye);

        

        {   // update direction

            vec3 oldir = rd;

            rd = cosHemi(N, s);

            rd = roughBlend(rd, oldir, N, sam.matid);

            eye += N * e * 10.0f;

        }

        col += mask * materials[sam.matid].emittance.rgb;

        mask *=  2.0* materials[sam.matid].reflectance.rgb * abs(dot(N, rd));

        

        if(absum(mask) < 0.000001)

            break;

    }

    

    return col;

}

void main(){

    ivec2 pix = ivec2(gl_GlobalInvocationID.xy);  

    ivec2 size = imageSize(color);

    if (pix.x >= size.x || pix.y >= size.y) return;

    

    uint s = uint(seed.z + 10000.0 * dot(seed.xy, gl_GlobalInvocationID.xy));

    vec2 aa = vec2(rand(s), rand(s)) * 0.5;

    vec2 uv = (vec2(pix + aa) / vec2(size))* 2.0 - 1.0;

    vec3 rd = normalize(toWorld(uv.x, uv.y, 0.0) - EYE); //random direction

    float a = luzpos.x;

    vec3 col = vec3(0.0,0.0, 0.0);

    for(int i = 0; i < calidad; i++){ // QIND

        col += clamp(trace(rd, EYE, s), vec3(0.0), vec3(1.0));

    }
    col = col/calidad;
    


    //Linea Original

    //vec3 col = clamp(trace(rd, EYE, s), vec3(0.0), vec3(1.0));

    // linea original

    vec3 oldcol = imageLoad(color, pix).rgb;


    //col = mix(oldcol, col, 1.0 / SAMPLES);

    //col = mix(oldcol, col, 0.3);
    imageStore(color, pix, vec4(col, 1.0));

}

