#define SWRT_LIGHTS_PER_BLOCK (4*SWRT_LIGHT_LAYERS)

#ifndef LIGHT_LIST_ACCESS_GLSL
#define LIGHT_LIST_ACCESS_GLSL

const uint INVALID_PACKED_LIST_LIGHT = 0u;
const ivec3 INVALID_UNPACKED_LIST_LIGHT = ivec3(0);

#define LIGHT_VALID_BIT    1u
#define LIGHT_NO_META_MASK 0x003fffffu
const int offsetToVox = (SWRT_SIZE-VOXELIZATION_SIZE)>>1;

const int swrtMaxDist = MAX_SWRT_LIGHT_DISTANCE;
const float maxPossibleLightLen = 124.5;

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
        uint o = layer<<2;
        uvec4 s = uvec4(list[o],list[o+1],list[o+2],list[o+3]);
        imageStore(lightSourceList,ivec3(areaPos.x,areaPos.y+layer,areaPos.z),s);
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
    uvec4 l1 = imageLoad(lightSourceList,areaPos);
    #if SWRT_LIGHT_LAYERS>=2
    uvec4 l2 = imageLoad(lightSourceList,ivec3(areaPos.x,areaPos.y+1,areaPos.z));
    #if SWRT_LIGHT_LAYERS>=3
    uvec4 l3 = imageLoad(lightSourceList,ivec3(areaPos.x,areaPos.y+2,areaPos.z));
    #if SWRT_LIGHT_LAYERS>=4
    uvec4 l4 = imageLoad(lightSourceList,ivec3(areaPos.x,areaPos.y+3,areaPos.z));
    #endif
    #endif
    #endif

    list[0]=l1.x;
    list[1]=l1.y;
    list[2]=l1.z;
    list[3]=l1.w;
    #if SWRT_LIGHT_LAYERS>=2
    list[4]=l2.x;
    list[5]=l2.y;
    list[6]=l2.z;
    list[7]=l2.w;
    #if SWRT_LIGHT_LAYERS>=3
    list[8 ]=l3.x;
    list[9 ]=l3.y;
    list[10]=l3.z;
    list[11]=l3.w;
    #if SWRT_LIGHT_LAYERS>=4
    list[12]=l4.x;
    list[13]=l4.y;
    list[14]=l4.z;
    list[15]=l4.w;
    #endif
    #endif
    #endif
}
#endif

uint uncheckedPackListedLight(ivec3 posRel){
    posRel+=swrtMaxDist;
    return uint((posRel.x<<15)|(posRel.y<<8)|(posRel.z<<1))|LIGHT_VALID_BIT;
}

ivec3 uncheckedUnpackListedLight(uint packedLight){
    return (ivec3(packedLight>>15,packedLight>>8,packedLight>>1)&0x7f)-swrtMaxDist;
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
        ret+=list[i]&1u;
    }
    return ret;
}

#endif
