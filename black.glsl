#version 430 core

layout(local_size_x = 8, local_size_y = 8) in;

layout(binding = 0, rgba32f) uniform image2D color;


void main(){

    ivec2 pix = ivec2(gl_GlobalInvocationID.xy);  

    ivec2 size = imageSize(color);

    if (pix.x >= size.x || pix.y >= size.y) return;

    

    // linea original

    //vec3 col = imageLoad(color, pix).rgb;
    vec3 col = vec3(0.0,0.0,0.0);

    imageStore(color, pix, vec4(col, 1.0));

}

