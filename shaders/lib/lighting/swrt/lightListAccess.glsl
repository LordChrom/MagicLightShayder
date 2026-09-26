#define SWRT_LIGHTS_PER_BLOCK (4*SWRT_LIGHT_LAYERS)

#ifndef LIGHT_LIST_ACCESS_GLSL
#define LIGHT_LIST_ACCESS_GLSL

const uint INVALID_PACKED_LIST_LIGHT = 0u;
const ivec3 INVALID_UNPACKED_LIST_LIGHT = ivec3(0);

#define LIGHT_VALID_BIT 0x8000u
const int offsetToVox = (SWRT_SIZE-VOXELIZATION_SIZE)>>1;

//TODO change packing scheme for more travel dist
const int swrtMaxDist = 15;
const float maxPossibleLightLen = 25.99;

uint modSwrtSize(uint x){
    #if (SWRT_SIZE&(SWRT_SIZE-1))
    return (x+0x10000u*SWRT_SIZE)%SWRT_SIZE;
    #else
    return x&uint(SWRT_SIZE-1);
    #endif
}
uvec3 modSwrtSize(uvec3 x){
    #if (SWRT_SIZE&(SWRT_SIZE-1))
    return (x+0x10000u*SWRT_SIZE)%SWRT_SIZE;
    #else
    return x&uint(SWRT_SIZE-1);
    #endif
}
int modSwrtSize(int x){ return int(modSwrtSize(uint(x)));}
ivec3 modSwrtSize(ivec3 x){ return ivec3(modSwrtSize(uvec3(x)));}

#if defined WRITES_LIGHT_LIST || defined READS_LIGHT_LIST
layout (rgba32ui) uniform
#ifndef WRITES_LIGHT_LIST
readonly
#endif
restrict uimage3D lightSourceList;
#endif

#ifdef WRITES_LIGHT_LIST
void setLightList(uint[SWRT_LIGHTS_PER_BLOCK] list, ivec3 areaPos, ivec3 unitShift){
    areaPos = modSwrtSize(areaPos+unitShift);
    areaPos.y*=SWRT_LIGHT_LAYERS;
    for(int layer=0;layer<SWRT_LIGHT_LAYERS;layer++){
        uvec4 s;
        for(int i=0;i<4;i++)
            s[i]=list[4*layer+i];
        imageStore(lightSourceList,areaPos,s);
        areaPos.y++;
    }
}

void clearLightList(ivec3 areaPos, ivec3 unitShift){
    areaPos = modSwrtSize(areaPos+unitShift);
    areaPos.y*=SWRT_LIGHT_LAYERS;
    for(int layer=0;layer<SWRT_LIGHT_LAYERS;layer++){
        imageStore(lightSourceList,areaPos,uvec4(0));
        areaPos.y++;
    }
}
#endif

#ifdef READS_LIGHT_LIST
void getLightList(out uint[SWRT_LIGHTS_PER_BLOCK] list, ivec3 areaPos, ivec3 unitShift){
    areaPos = modSwrtSize(areaPos+unitShift);
    areaPos.y*=SWRT_LIGHT_LAYERS;

    for(int layer=0;layer<SWRT_LIGHT_LAYERS;layer++){
        uvec4 s = imageLoad(lightSourceList,areaPos);
        for(int i=0;i<4;i++)
            list[layer*4+i]=s[i];
        areaPos.y++;
    }
}
#endif

uint uncheckedPackListedLight(ivec3 posRel){
    posRel+=swrtMaxDist;
    return uint((posRel.x<<10)|(posRel.y<<5)|(posRel.z))|LIGHT_VALID_BIT;
}

ivec3 uncheckedUnpackListedLight(uint packedLight){
    ivec3 ret = ivec3(packedLight>>10,packedLight>>5,packedLight)&0x1f;
    ret-=swrtMaxDist;
    return ret;
}

uint packListedLight(ivec3 posRel){
    if(max(max(abs(posRel.x),abs(posRel.y)),abs(posRel.z))>swrtMaxDist)
        return INVALID_PACKED_LIST_LIGHT;
    return uncheckedPackListedLight(posRel);
}

ivec3 unpackListedLight(uint packedLight){
    if(!bool(packedLight&LIGHT_VALID_BIT))
        return INVALID_UNPACKED_LIST_LIGHT;
    return uncheckedUnpackListedLight(packedLight);
}

float packedListedLightLen(uint packedLight){
    if(!bool(packedLight&LIGHT_VALID_BIT))
        return maxPossibleLightLen;
    return length(uncheckedUnpackListedLight(packedLight));
}

uint addToPackedLight(uint packedLight, ivec3 change){
    if(!bool(packedLight&LIGHT_VALID_BIT))
        return INVALID_PACKED_LIST_LIGHT;
    ivec3 retUnpacked = uncheckedUnpackListedLight(packedLight)+change;
    return packListedLight(retUnpacked);
}


uint countLights(uint[SWRT_LIGHTS_PER_BLOCK] list){
    uint ret=0u;
    for(int i=0;i<SWRT_LIGHTS_PER_BLOCK;i++){
        ret+=uint(bool(list[i]&LIGHT_VALID_BIT));
    }
    return ret;
}

#endif
