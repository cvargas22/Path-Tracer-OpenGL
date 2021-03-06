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

layout(binding=8) uniform DIR_BUF
{
    vec3 luzdir;
};

layout(binding=9) uniform ANG_LUZ
{
    float angluz;
};


#define EYE eye.xyz

#define NEAR nfwh.x

#define FAR nfwh.y

#define WIDTH nfwh.z

#define HEIGHT nfwh.w

#define SAMPLES seed.w

#define CBOUNCES 3

#define CSAMPLES 512

struct Material{

    vec4 reflectance, emittance;

};

layout(binding=3) buffer SDF_BUF{   

    Material materials[22];

};

#define ROUGHNESS(i) materials[(i)].emittance.w
#define ABSORB(i) materials[(i)].reflectance.w

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

//Cilindro infinito

MapSample cylinder(vec3 ray,vec3 location, vec3 c,int mat){

    vec3 p = ray - location;

    return MapSample(distance(p.xy,c.xy) -c.z, mat);
}

//Cilindro capeado
MapSample cylinderCap(vec3 ray,vec3 location, vec2 h,int mat){

    vec3 p = ray - location;

    vec2 d = abs(vec2(length(p.xz),p.y)) - h;
    
    return MapSample(min(max(d.x,d.y),0.0)+length(max(d,0.0)), mat);
}


//Cono
MapSample cone(vec3 ray, vec3 location, vec3 c, int mat)
{

    vec3 p = ray - location;

    vec2 q = vec2(length(p.xz), p.y);

    float d1 = -p.y-c.z;

    float d2 = max(dot(q, c.xy), p.y);

    return MapSample(length(max(vec2(d1, d2), 0.0)) + min(max(d1, d2), 0.), mat);
}

//Prisma Triangular

MapSample triPrism(vec3 ray, vec3 location, vec2 h, int mat)
{
    vec3 p = ray - location;
    vec3 q = abs(p);
    return MapSample(max(q.z-h.y,max(q.x*0.866025+p.y*0.5,-p.y)-h.x*0.5), mat);
}

MapSample box(vec3 ray, vec3 location, vec3 dimension, int mat){

    vec3 d = abs(ray - location) - dimension;

    return MapSample(vmax(d), mat);

}


MapSample plane(vec3 ray, vec3 location, vec3 normal, int mat){

    return MapSample(dot(ray - location, normal), mat);


}



MapSample light(vec3 ray, vec3 location, vec3 normal, int mat){
    
    return MapSample(dot(ray-location, normal), mat);
}

MapSample join(MapSample a, MapSample b){

    if(a.distance <= b.distance)

        return a;

    return b;

}

//rotacion
/*vec3 opTx(vec3 ray, vec3 location, mat4 m )
{
    vec3 p = ray - location;
    vec3 q = invert(m)*p;
    return primitive(q);
}*/


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

        MapSample a = triPrism(ray,

        vec3(1.0f, 1.8f, 0.0f),

        vec2(1.0f, 2.2f),

        18);

        a = join(a, box(ray,    

        vec3(1.0f, 0.5f, 0.0f),

        vec3(0.8f, 0.9f, 2.1f),

        15));

        a = join(a, plane(ray, // Suelo

        vec3(0.0f, 0.0f, 0.0f),

        vec3(0.0f, 1.0f, 0.0f),

        16)); //verde pasto


         // Montañas

        a = join(a, sphere(ray, // chrome spheres

        vec3(-30.0f,0.0f,0.0f),

        6.0f,

        17));

        a = join(a, sphere(ray, // chrome spheres

        vec3(-25.0f,0.0f,-10.0f),

        6.5f,

        17)); //cafe

        a = join(a, sphere(ray, // chrome spheres

        vec3(-20.0f,0.0f,-20.0f),

        5.5f,

        17));

        a = join(a, sphere(ray, // chrome spheres

        vec3(-10.0f,0.0f,-25.0f),

        7.5f,

        17));

        a = join(a, sphere(ray, // chrome spheres

        vec3(2.0f,0.0f,-25.0f),

        7.5f,

        17));

         a = join(a, sphere(ray, // chrome spheres

        vec3(15.0f,0.0f,-25.0f),

        7.5f,

        17));

        a = join(a, sphere(ray, // chrome spheres

        vec3(25.0f,0.0f,-18.0f),

        5.5f,

        17));

        a = join(a, sphere(ray, // chrome spheres

        vec3(35.0f,0.0f,-10.0f),

        8.5f,

        17));


        // Arboles

        
        a = join(a, cylinderCap(ray,

        vec3(-4.0f, 0.4f, -3.0f),

        vec2(0.1f, 0.6f),

        21));

         
        a = join(a, cone(ray,

        vec3(-4.0f, 2.4f, -3.0f), //Posicion
        vec3(1.0f, 0.3f,1.4f), //Dimensiones

        16));

      
        a = join(a, cylinderCap(ray,

        vec3(-5.0f, 0.4f, -3.0f),

        vec2(0.1f, 0.6f),

        21));
         
        a = join(a, cone(ray,

        vec3(-5.0f, 2.4f, -3.0f), //Posicion
        vec3(1.0f, 0.3f,1.4f), //Dimensiones

        16));


        a = join(a, cylinderCap(ray,

        vec3(-6.0f, 0.4f, -3.0f),

        vec2(0.1f, 0.6f),

        21));
         
        a = join(a, cone(ray,

        vec3(-6.0f, 2.4f, -3.0f), //Posicion
        vec3(1.0f, 0.3f,1.4f), //Dimensiones

        16));


        a = join(a, cylinderCap(ray,

        vec3(-7.0f, 0.4f, -2.0f),

        vec2(0.1f, 0.6f),

        21));
         
        a = join(a, cone(ray,

        vec3(-7.0f, 2.4f, -2.0f), //Posicion
        vec3(1.0f, 0.3f,1.4f), //Dimensiones

        16));


        a = join(a, cylinderCap(ray,

        vec3(-6.0f, 0.4f, -2.0f),

        vec2(0.1f, 0.6f),

        21));
         
        a = join(a, cone(ray,

        vec3(-6.0f, 2.4f, -2.0f), //Posicion
        vec3(1.0f, 0.3f,1.4f), //Dimensiones

        16));

        a = join(a, cylinderCap(ray,

        vec3(-5.0f, 0.4f, -2.0f),

        vec2(0.1f, 0.6f),

        21));
         
        a = join(a, cone(ray,

        vec3(-5.0f, 2.4f, -2.0f), //Posicion
        vec3(1.0f, 0.3f,1.4f), //Dimensiones

        16));

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

                ABSORB(matid) * reflect(oldir, N)), 

            newdir, 

            ROUGHNESS(matid)

            )

        );

}

float absum(vec3 a){

    return abs(a.x) + abs(a.y) + abs(a.z);

}

float intersect(vec3 ro, vec3 rd, MapSample h){

    float res = -1.0;
    float tmax = 100.0;
    float t = 0.01;
    for(int i=0; i<CSAMPLES; i++ )
    {
        h = map(ro+rd*t);
        if( abs(h.distance)<0.0001 || t>tmax ) break;
        t +=  abs(h.distance);

        ro = ro + rd * h.distance;
    }
    
    if( t<tmax ) res = t;

    return res;
}

float shadow(vec3 ro,vec3 rd, MapSample h)
{
    float res = 0.0;
    
    float tmax = 100.0;
    
    float t = 0.001;
    for(int i=0; i<80; i++ )
    {
        h = map(ro+rd*t);
        if(abs(h.distance)<0.0001 || t>tmax) break;
        t += abs(h.distance);
        //res = min( res, k*(h.distance/t));
    }

    if( t>tmax ) res = 1.0;
    
    return res;
}
 

//Sun and Sky variables
vec3 sunDir = normalize(luzdir);
vec3 sunCol = materials[0].emittance.rgb; 
vec3 skyCol =  2.0*vec3(0.2,0.35,0.5);
float cal = 1.0; //calibracion colores
float skycal = 1.0; //calibracion intensidad cielo

vec3 trace(vec3 rd, vec3 eye, inout uint s){
    
    float e = 0.001;
    float fdis = 0.0;
    vec3 col = vec3(0.0, 0.0, 0.0);
    vec3 mask = vec3(1.0, 1.0, 1.0);


    for(int i = 0; i < CBOUNCES; i++){    // bounces

        MapSample sam;
        skycal = max(0.02, sin(angluz));
        float skycal2 = max(0.002, sin(angluz));

        //float t = intersect( eye, rd, sam);
        float res = -1.0;
        float tmax = 10000.0;
        float t = 0.01;
        for(int j=0; j<CSAMPLES; j++ )
        {
            //sam = map(eye+rd*t);
            sam = map(eye);
            if( abs(sam.distance)<0.0001 || t>tmax ) break;
            t +=  abs(sam.distance);

            eye = eye + rd * sam.distance;
        }        
        if( t<tmax ) res = t;


        float sundot = clamp(dot(rd, sunDir),0.0,1.0);

        //Añadir color del cielo cuando no intersecta con nada
        if( res < 0.0 )
        {
            
            if( i==0 ) {

                // sky
                col = vec3(0.2,0.5,0.85)*1.1 - rd.y*rd.y*0.5;
                col = skycal2*mix( col, 0.85*vec3(0.7,0.75,0.85), pow( 1.0-max(rd.y,0.0), 4.0 ) );
                //col += rand()*vec3(1.0f, 1.0f, 1.0f);

                // sun
                col += 0.25*vec3(1.0,0.7,0.4)*pow( sundot,5.0 );
                col += 0.25*vec3(1.0,0.8,0.6)*pow( sundot,64.0 );
                col += 0.2*vec3(1.0,0.8,0.6)*pow( sundot,512.0 );
            }
            else{
                col = col*2;
            }
            break;
            
        }

        if( i==0 ) fdis = t;

        //vec3 pos = eye + rd * t;
        //eye = eye + rd * t;

        vec3 N = map_normal(eye);


    

        vec3 iColor = vec3(0.0, 0.0, 0.0);


        //Calibrar contribucion de la luz en el modelo por cada rebote 
        
        // light 1        
        float sunDif =  max(0.0, dot(sunDir, N));
        float sunSha = 1.0; if( sunDif > 0.00001 ) sunSha = shadow( eye + N*e, sunDir, sam);
        iColor += sunCol * sunDif * sunSha;
        
        // todo - add back direct

    
        // light 2
        vec3 skyPoint = cosHemi(N,s);
        float skySha = shadow( eye + N*e, skyPoint, sam);
        skycal = max(0.02, sin(angluz));
        iColor += skycal * skyCol * skySha;

        col += mask * materials[sam.matid].emittance.rgb;
        col +=  mask * iColor * materials[sam.matid].reflectance.rgb;
        mask *=  cal * materials[sam.matid].reflectance.rgb * abs(dot(N, rd));

    
        {   // update direction

            vec3 oldir = rd;

            rd = cosHemi(N, s);

            rd = roughBlend(rd, oldir, N, sam.matid);

            eye += N * e * 10.0f;
    
        }

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


    col = pow( col, vec3(0.8,0.85,0.9) );
    
    
    imageStore(color, pix, vec4(col, 1.0));

}

