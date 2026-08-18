float distortZ(float z){
    return 0.5*z;
}


#ifdef TAA
uniform vec2 scaledScreenDim;
#include "/lib/util/taaJitter.glsl"
#endif

#define MAX_SHADOW_CASCADE 7
#define INDIVIDUAL_CASCADE_SCALE 3.0

#ifdef CASCADED_SHADOWS
float getFloatMaxLevel(float dist){
    return -log2(max(0.001,dist));
}
float getFloatMaxLevel(vec2 pos){
    return getFloatMaxLevel(max(abs(pos.x),abs(pos.y)));
}
int getMaxLevel(vec2 pos){
    return int(getFloatMaxLevel(pos));
}
int getMaxLevel(float pos){
    return int(getFloatMaxLevel(pos));
}

vec2 getLevelCenter(int level){
    return (vec2(level/3,level%3)-1)*2.0/3.0;
}

float getLevelScale(int level){
    return float(1<<level);
}

vec2 levelDistort(vec2 shadowpos, int level){
    shadowpos*=getLevelScale(level);
    #ifdef TAA
    shadowpos+=INDIVIDUAL_CASCADE_SCALE*shadowJitter();
    #endif
    shadowpos = clamp(shadowpos,-1,1);
    return shadowpos/INDIVIDUAL_CASCADE_SCALE+getLevelCenter(level);
}

vec2 distort(vec2 shadowpos){
    if(shadowpos.x<-1 || shadowpos.y<-1 || shadowpos.x>1 || shadowpos.y>1)
        return vec2(-100);
    return levelDistort(shadowpos,clamp(getMaxLevel(shadowpos*1.01),0,MAX_SHADOW_CASCADE));
}

vec3 distort(vec3 shadowpos, float noise){
    int level = int(getFloatMaxLevel(shadowpos.xy*1.07)-0.04*noise);
    return vec3(levelDistort(shadowpos.xy, min(level,MAX_SHADOW_CASCADE)),distortZ(shadowpos.z));
}
#else
vec2 distort(vec2 shadowpos){
    shadowpos = shadowpos/((pow(abs(shadowpos),vec2(0.8)))+0.08);
    #ifdef TAA
    shadowpos+=shadowJitter();
    #endif
    return shadowpos;
}
vec3 distort(vec3 shadowpos, float noise){
    return vec3(distort(shadowpos.xy),distortZ(shadowpos.z));
}
#endif

vec3 distort(vec3 shadowpos){
    return vec3(distort(shadowpos.xy),distortZ(shadowpos.z));
}