#ifndef CAMERA_H
#define CAMERA_H

#define GLM_SWIZZLE
#include "glm/glm.hpp"
#include "glm/gtc/matrix_transform.hpp"

static const glm::vec3 up_vec = glm::vec3(0.0f, 1.0f, 0.0f);

inline glm::vec3 getRight(const glm::mat4& m){
    return glm::vec3(m[0][0], m[1][0], m[2][0]);
}
inline glm::vec3 getUp(const glm::mat4& m){
    return glm::vec3(m[0][1], m[1][1], m[2][1]);
}
inline glm::vec3 getForward(const glm::mat4& m){
    return glm::vec3(-m[0][2], -m[1][2], -m[2][2]);
}

class Camera{
    glm::mat4 P, V;
    glm::vec3 m_eye, m_at;
    float m_fov, m_whratio, m_near, m_far;
public:
    Camera(float fov=glm::radians(60.0f), float ratio=16.0f/9.0f, float near=0.1f, 
        float far=100.0f, const glm::vec3& eye=glm::vec3(0.0f), 
        const glm::vec3& at=glm::vec3(0.0f, 0.0f, -1.0f)) 
        : m_eye(eye), m_at(at), m_fov(fov), m_whratio(ratio), m_near(near), m_far(far){
        P = glm::perspective(m_fov, m_whratio, m_near, m_far);
        update();
    }
    inline void update(){
        V = glm::lookAt(m_eye, m_at, up_vec);
    }
    inline void lookAt(const glm::vec3& at){
        m_at = at;
    }
    inline void resize(int width, int height){
        m_whratio = (float)width / (float)height;
        P = glm::perspective(m_fov, m_whratio, m_near, m_far);
    }
    inline void setFov(float fov){
        m_fov = glm::radians(fov);
        P = glm::perspective(m_fov, m_whratio, m_near, m_far);
    }
    inline const glm::vec3& getEye(){return m_eye;}
    inline const glm::vec3& getAt(){return m_at;}
    inline float getNear()const{return m_near;}
    inline float getFar()const{return m_far;}
    inline float getFov()const{return m_fov;}
    inline void setEye(const glm::vec3& eye){m_eye = eye;}
    inline void move(const glm::vec3& v){
        auto dv = v.x * getRight(V) + v.y * getUp(V) - v.z * getForward(V);
        m_eye += dv;
        m_at += dv;
    }
    void pitch(float amt){
        m_at += amt * getUp(V);
        auto forward = glm::normalize(m_at - m_eye);
        if(fabsf(forward.y) > 0.6f)
            m_at -= amt * getUp(V);
    }
    void yaw(float amt){
        m_at -= amt * getRight(V);
    }
    inline const glm::mat4& getV(){return V;}
    inline const glm::mat4& getP(){return P;}
    inline glm::mat4 getVP()const{return P * V;}
    inline glm::mat4 getIVP()const{return glm::inverse(P * V);}
    inline glm::vec3 getAxis()const{ return normalize(m_at - m_eye);}
    inline void setPlanes(float near, float far){
        m_near = near; m_far = far;
        P = glm::perspective(m_fov, m_whratio, m_near, m_far);
    }
    inline float getAR(){return m_whratio;}
};
#endif
