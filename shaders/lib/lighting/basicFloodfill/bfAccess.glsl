#ifndef BASIC_FLOODFILL_ACCESS_GLSL
#define BASIC_FLOODFILL_ACCESS_GLSL
uint modFloodfillSize(uint x){
    #if (FLOODFILL_SIZE&(FLOODFILL_SIZE-1))
    return (x+0x10000u*FLOODFILL_SIZE)%FLOODFILL_SIZE;
    #else
    return x&uint(FLOODFILL_SIZE-1);
    #endif
}
uvec3 modFloodfillSize(uvec3 x){
    #if (FLOODFILL_SIZE&(FLOODFILL_SIZE-1))
    return (x+0x10000u*FLOODFILL_SIZE)%FLOODFILL_SIZE;
    #else
    return x&uint(FLOODFILL_SIZE-1);
    #endif
}
int modFloodfillSize(int x){ return int(modFloodfillSize(uint(x)));}
ivec3 modFloodfillSize(ivec3 x){ return ivec3(modFloodfillSize(uvec3(x)));}

#ifdef WRITES_FLOOD
layout (rgba8) uniform writeonly restrict image3D floodfillVox;

void setFloodData(vec4 data, ivec3 areaPos, ivec3 areaShift){
    areaPos = modFloodfillSize(areaPos+areaShift);
    ivec3 p;
    for(p.x=areaPos.x;p.x<=FLOODFILL_SIZE;p.x+=FLOODFILL_SIZE)
    for(p.y=areaPos.y;p.y<=FLOODFILL_SIZE;p.y+=FLOODFILL_SIZE)
    for(p.z=areaPos.z;p.z<=FLOODFILL_SIZE;p.z+=FLOODFILL_SIZE)
    imageStore(floodfillVox,p,data);
}
#endif

#ifdef SAMPLES_FLOOD
uniform sampler3D floodfillSampler;

vec4 getFloodData(ivec3 areaPos, ivec3 areaShift){
    return texelFetch(floodfillSampler,modFloodfillSize(areaPos+areaShift),0);
}
#endif

#endif