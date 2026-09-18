#ifndef VOLUME_SHIFTING_GLSL
#define VOLUME_SHIFTING_GLSL
uniform vec3 globalOrigin, previousGlobalOrigin;
uniform int frameCounter;

vec3 getGlobalOrigin(float scale){
    return floor(globalOrigin/scale)*scale;
}
vec3 getPreviousGlobalOrigin(float scale){
    return floor(previousGlobalOrigin/scale)*scale;
}
ivec3 getAreaShift(float scale, vec3 origin){
    return ivec3(floor(origin/scale));
}
ivec3 getAreaShift(float scale){return ivec3(floor(globalOrigin/scale));}
ivec3 getCascadedAreaShift(uint cascadeLevel){return getAreaShift(MIN_SCALE*float(1<<cascadeLevel));}
ivec3 getPreviousAreaShift(float scale){return ivec3(floor(previousGlobalOrigin/scale));}
ivec3 getPreviousCascadedAreaShift(uint cascadeLevel){return getPreviousAreaShift(MIN_SCALE*float(1<<cascadeLevel));}

ivec3 getUnitShift(){
    return ivec3(floor(globalOrigin));
}
ivec3 getPreviousUnitShift(){
    return ivec3(floor(previousGlobalOrigin));
}
#endif