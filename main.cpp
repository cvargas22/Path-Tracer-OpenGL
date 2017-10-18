#include "myglheaders.h"

#include "camera.h"

#include "debugmacro.h"

#include "window.h"

#include "input.h"

#include "glprogram.h"

#include "compute_shader.h"

#include "glscreen.h"

#include "UBO.h"

#include "SSBO.h"

#include "timer.h"

#include "texture.h"

#include "time.h"

#include <random>

#include "string.h"

#include <fstream>



using namespace std;



constexpr size_t NUM_MATERIALS = 32;



struct Uniforms{

    glm::mat4 IVP;

    glm::vec4 eye;

    glm::vec4 nfwh;

    glm::vec4 seed;

    
};


struct Esferas{

    glm::vec3 pos1;
    glm::vec3 pos2;
    glm::vec3 pos3;
    glm::vec3 pos4;
    glm::vec3 pos5;

};

struct Material{

    glm::vec4 reflectance, emittance;

};



struct SDF_BUF{

    Material materials[NUM_MATERIALS];

};



float frameBegin(unsigned& i, float& t){

    float dt = (float)glfwGetTime() - t;

    t += dt;

    i++;

    if(t >= 3.0f){

        float ms = (t / i) * 1000.0f;

        printf("ms: %.6f, FPS: %.3f\n", ms, i / t);

        i = 0;

        t = 0.0f;

        glfwSetTime(0.0);

    }

    return dt;

}

#define MIN(a, b) ((a) < (b) ? (a) : (b))

#define MAX(a, b) ((a) > (b) ? (a) : (b))



bool read_map(float* buf, int len, const char* filename){

    ifstream fs(filename);

    if(!fs.is_open())return false;

    

    for(int i = 0; i < len && fs.good(); i++){

        fs >> buf[i];

    }

    

    fs.close();

    return true;

}



inline float absSum(const glm::vec3& v){

    return fabsf(v.x) + fabsf(v.y) + fabsf(v.z);

}



bool v3_equal(const glm::vec3& a, const glm::vec3& b){

    return absSum(a - b) == 0.0f;

}



int main(int argc, char* argv[]){

    srand(time(NULL));

    int WIDTH = 1280, HEIGHT = 720;

    //int WIDTH = 3840, HEIGHT = 2160;
    int test = 1;
    string nombre_test = "depth1.glsl";
    int calidad = 1;


    if(argc == 5){

        WIDTH = atoi(argv[1]);

        HEIGHT = atoi(argv[2]);

        test = atoi(argv[3]);

        if(test == 1){
            nombre_test = "depth1.glsl";
        }
        if(test == 2){
            nombre_test = "depth2.glsl";
        }
        if(test == 3){
            nombre_test = "test3.glsl";
        }
        if(test == 4){
            nombre_test = "test4.glsl";
        }

        calidad = atoi(argv[4]);

    }
    else{
        printf("%s\n", "Ejecutar como ./Renderer.exe WIDTH HEIGHT escenario calidad");
        exit(EXIT_FAILURE);
    }
    
    
    //Carga de propiedades del material
    SDF_BUF sdf_buf;

    if(!read_map((float*)&sdf_buf.materials, sizeof(Material) * NUM_MATERIALS, "map.txt")){

        puts("Could not open map.txt");

        return 1;

    }

    
    //Variables camara
    Camera camera;

    camera.resize(WIDTH, HEIGHT);

    camera.setEye({-1.0f, 4.0f, 10.0f});

    camera.lookAt({0.0f, 0.0f, 0.0f});

    camera.update();

    

    const unsigned layoutSize = 8;

    const unsigned callsizeX = WIDTH / layoutSize + ((WIDTH % layoutSize) ? 1 : 0);

    const unsigned callsizeY = HEIGHT / layoutSize + ((HEIGHT % layoutSize) ? 1 : 0);
    //printf("%i %i\n",callsizeX, callsizeY );

    

    Window window(WIDTH, HEIGHT, 4, 3, "gputracer");

    Input input(window.getWindow());

    

    GLProgram color("vert.glsl", "frag.glsl");

    ComputeShader depth(nombre_test);

    ComputeShader black("black.glsl");

    Texture4f colTex(WIDTH, HEIGHT);

    colTex.setCSBinding(0);

    GLScreen screen;

    Timer timer;

    

    Uniforms uni;

    uni.IVP = camera.getIVP();

    uni.eye = glm::vec4(camera.getEye(), 1.0f);

    uni.nfwh = glm::vec4(camera.getNear(), camera.getFar(), (float)WIDTH, (float)HEIGHT);

    UBO unibuf(&uni, sizeof(uni), 2);



    

    SSBO sdfbuf(&sdf_buf, sizeof(sdf_buf), 3);

    

    // luz y esferas dinamicas ESCENARIO 1
    glm::vec3 luzpos(0.0,5.0,-5.0);
    glm::vec3 luzoffset(0.0,5.0,0.0);

    // luz ESCENARIO 2
    glm::vec3 luzdir(-0.3, 1.3, 0.5);
    glm::vec3 diroffset(0.0,1.3,0.5);

    //Posicion esferas
    Esferas loc;
    loc.pos1 = glm::vec3(-1.0,0.0,0.0);
    loc.pos2 = glm::vec3(-5.0,0.0,0.0);
    loc.pos3 = glm::vec3(0.0,3.0,0.0);
    loc.pos4 = glm::vec3(0.0,3.0,0.0);
    loc.pos5 = glm::vec3(0.0,3.0,0.0);
    UBO locbuf(&loc, sizeof(loc), 6);

    //switch paredes
    int on = 0;

    UBO calbuf(&calidad,sizeof(calidad), 7);

    UBO posbuf(&luzpos, sizeof(luzpos), 4);
    
    UBO wallbuf(&on, sizeof(on), 5);

    UBO dirbuf(&luzdir, sizeof(luzdir), 8);

    //Variables movimiento de luz en escenario 1
    //float angulo2 = 0.0f * (3.14 / 180);
    float angulo2 = 0.0f;
    UBO angluz(&angulo2, sizeof(angulo2), 9);



    input.poll();

    unsigned i = 0;

    float frame = 1.0f;

    float irm = 1.0f / RAND_MAX;

    float t = (float)glfwGetTime();

    //Variables movimiento de luz en escenario 1
    float angulo = 0.0f;

    float radio = 4.0;
    
    bool movLuz = true; //Flag para movimiento de luz


    float radio2 = 10.0;

 

    while(window.open()){

        glm::vec3 eye = camera.getEye();

        glm::vec3 at = camera.getAt();

        input.poll(frameBegin(i, t), camera);

        input.poll(luzpos);

        if(!v3_equal(eye, camera.getEye()) || !v3_equal(at, camera.getAt()))

            frame = 2;

    

        if(((int)(frame) & 31) == 31)

            printf("SPP: %f\n", frame);

        //Sacar paredes
        /*if (glfwGetKey (window.getWindow(), GLFW_KEY_P)) {
            on = 1;
            
        }
        if (glfwGetKey (window.getWindow(), GLFW_KEY_O)) {
            on = 0;
            
        }*/


        if(movLuz){
             luzpos = glm::vec3(cos(angulo)*radio,0.0, sin(angulo)*radio) + luzoffset; //movimiento de luz en test 1
             angulo+=0.01;
             
        }

        if (glfwGetKey (window.getWindow(), GLFW_KEY_U)) {
            movLuz= false;
            
        }

        luzdir = glm::vec3(cos(angulo2)*radio2, sin(angulo2)*radio2, 0.0) + diroffset; // movimiento de luz en test 3 y 4
        //angulo2+=0.01 * (3.14 / 180);
        angulo2+=0.01;
        //printf("angluz = %f    cos(angluz) = %f\n", angulo2, sin(angulo2));

        uni.IVP = camera.getIVP();

        uni.eye = glm::vec4(camera.getEye(), 1.0f);

        uni.seed = glm::vec4(rand() * irm, rand() * irm, rand() * irm, frame);

        unibuf.upload(&uni, sizeof(uni));
  

        posbuf.upload(&luzpos, sizeof(luzpos));
        wallbuf.upload(&on, sizeof(on));
        locbuf.upload(&loc, sizeof(loc));
        calbuf.upload(&calidad, sizeof(calidad));
        dirbuf.upload(&luzdir, sizeof(luzdir));
        angluz.upload(&angulo2, sizeof(angulo2));

        //black.bind();

        //black.call(callsizeX, callsizeY, 1);

        depth.bind();

        depth.call(callsizeX, callsizeY, 1);

        glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

        

        color.bind();

        colTex.bind(0, "color", color);

        screen.draw();

        

        window.swap();

        frame = MIN(frame + 1.0f, 1000000.0f);

    }



    return 0;

}

