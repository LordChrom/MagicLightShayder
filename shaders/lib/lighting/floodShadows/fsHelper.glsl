#ifndef VOXEL_HELPER
#define VOXEL_HELPER
#include "/lib/settings.glsl"
#include "/lib/voxelStorage/volumeShifting.glsl"
#include "/lib/voxelStorage/blockPacking.glsl"

#define PackedLight uvec4

//caps out at 31 but its whatever
uint countTrailingZeroes(uint x){
//    return uint(findLSB(x))&0x1fu;
    uint ret = 0;
    for(uint bits = 16; bits>=2; bits>>=1){
        bool bitsInLowerHalf = bool(x&((1u<<bits)-1u));
        ret=bitsInLowerHalf?ret:ret+bits;
        x  =bitsInLowerHalf?x:x>>bits;
    }
    ret+=((~x)&0x1u);
    return ret;
}

uint getVariableCascadeLevel(uint frame){
    uint trailingZeroes = countTrailingZeroes(frame);
    #ifdef DOUBLE_PROC
    return trailingZeroes+1;
    #else
    return trailingZeroes;
    #endif
}

uint modAreaSize(uint x){
    #if (AREA_SIZE&(AREA_SIZE-1))
    return (x+0x10000u*AREA_SIZE)%AREA_SIZE;
    #else
    return x&uint(AREA_SIZE-1);
    #endif
}
uvec3 modAreaSize(uvec3 x){
    #if (AREA_SIZE&(AREA_SIZE-1))
    return (x+0x10000u*AREA_SIZE)%AREA_SIZE;
    #else
    return x&uint(AREA_SIZE-1);
    #endif
}
int modAreaSize(int x){ return int(modAreaSize(uint(x)));}
ivec3 modAreaSize(ivec3 x){ return ivec3(modAreaSize(uvec3(x)));}


//in order from 0 to 5, -x,+x,-y,+y,-z,+z
ivec3 lVec(uint axis){
    int lowerSign = -1+((int(axis)&1)<<1);
    axis>>=1;
    return ivec3(axis==0?lowerSign:0,axis==1?lowerSign:0,axis==2?lowerSign:0);
//    return lowerSign*ivec3(axis==0,axis==1, axis==2);
}

ivec3 aVec(uint axis){
    axis>>=1;
    return ivec3(axis==2,axis==0,axis==1);
}

ivec3 bVec(uint axis){
    axis>>=1;
    return ivec3(axis==1,axis==2,axis==0);
}

//output.xyz is area xyz
ivec3 worldPosToArea(vec3 pos, float scale){
    pos -= getGlobalOrigin(scale);
    pos = floor(pos/scale+(AREA_SIZE*0.5));
    return ivec3(pos);
}

float getScale(uint cascadeLevel){
    return MIN_SCALE*float(1<<cascadeLevel);
}

uint scaleToCascadeLevel(float scale){
    scale/=MIN_SCALE;
    return countTrailingZeroes(uint(scale));
}

uint getCascadeLevel(vec3 worldPos){
    vec3 pos = worldPos - globalOrigin;
    pos = abs(pos/(0.25*MIN_SCALE*AREA_SIZE));
    float maxDist = max(max(pos.x,pos.y),pos.z);
    uint cascade = uint(max(0,floor(log2(maxDist))));
    float scale = getScale(cascade);

    //TODO make more efficient
    pos = worldPos - getGlobalOrigin(scale);
    pos = abs(floor(pos/scale));
    if((scale>1) && (max(max(pos.x,pos.y),pos.z)>=(AREA_SIZE*0.5))){
        #ifdef DEBUG_SPLIT_VOXELS
        if(frameCounter%100<=50)
        #endif
        cascade++;
        ;
    }
    return cascade;
}

bool voxelIsSplit(ivec3 areaPos, ivec3 areaShift, uint cascadeLevel){
    if(int(cascadeLevel)<=-int(round(log2(MIN_SCALE))))
        return false;
    areaPos = modAreaSize(areaPos);
    return (
        (areaPos.x==0)||
        (areaPos.y==0)||
        (areaPos.z==0)
    );
}

bool isVoxelInBounds(vec3 worldPos){
    const float maxDist = 0.5*AREA_SIZE*MIN_SCALE*(1<<(NUM_CASCADES-1));
    worldPos = abs(worldPos-getGlobalOrigin(MAX_SCALE));
    return (worldPos.x<=maxDist) && (worldPos.y<=maxDist) && (worldPos.z<=maxDist);
}

uint zoneOffset(uint axis, uint layer, uint cascadeLevel){
    return ((cascadeLevel<<16u)|(0xffu&(layer+uint(MEM_LAYERS)*axis)));
}

uint areaOffset(uint cascadeLevel){
    return cascadeLevel<<16u;
}

ivec3 areaToZoneSpace(ivec3 areaPos, uint axis){
    ivec3 ret = bool(axis&4u) ? areaPos :
    (bool(axis&2u)?areaPos.zxy:areaPos.yzx);
    ret.z=bool(axis&1u)?ret.z:((AREA_SIZE-1)-ret.z);
    return ret;
}

vec3 areaToZoneSpaceRelative(vec3 areaPos, uint axis){
    vec3 ret = bool(axis&4u) ? areaPos :
    (bool(axis&2u)?areaPos.zxy:areaPos.yzx);
    ret.z=bool(axis&1u)?ret.z:-ret.z;
    return ret;
}

ivec3 areaToZoneSpaceRelative(ivec3 areaPos, uint axis){
    ivec3 ret = bool(axis&4u) ? areaPos :
    (bool(axis&2u)?areaPos.zxy:areaPos.yzx);
    ret.z=bool(axis&1u)?ret.z:-ret.z;
    return ret;
}

ivec3 zoneToAreaSpace(ivec3 zonePos, uint axis){
    zonePos.z=bool(axis&1u)?zonePos.z:((AREA_SIZE-1)-zonePos.z);

    return bool(axis&4u) ? zonePos:
    (bool(axis&2u)?zonePos.yzx:zonePos.zxy);
}

vec3 zoneToAreaSpaceRelative(vec3 zonePos, uint axis){
    zonePos.z=bool(axis&1u)?zonePos.z:-zonePos.z;

    return bool(axis&4u) ? zonePos:
    (bool(axis&2u)?zonePos.yzx:zonePos.zxy);
}

ivec3 zoneToAreaSpaceRelative(ivec3 zonePos, uint axis){
    zonePos.z=bool(axis&1u)?zonePos.z:-zonePos.z;

    return bool(axis&4u) ? zonePos:
    (bool(axis&2u)?zonePos.yzx:zonePos.zxy);
}

//input is is absolute world space, output is world space distance from center of voxel
vec3 subVoxelOffset(vec3 pos, float scale){
    return (fract(pos/scale)-0.5)*scale;
}

//works with either area pos or zone pos
ivec3 toMemPos(ivec3 pos, ivec3 spaceShift, uint memOffset){
    pos += spaceShift;
    pos = modAreaSize(pos);
    pos.yz+=AREA_SIZE*(0xffff&ivec2(memOffset>>16u,memOffset));
    return pos;
}

ivec3 upperCascadeAreaPos(ivec3 areaPos, ivec3 areaShift){
    return ((areaPos+(areaShift&1))>>1)+(AREA_SIZE>>2);
}

//sets innerAreaPos to be the least voxel that maps to the upper cascade voxel
ivec3 upperCascadeAreaPosForSeamFiller(inout ivec3 areaPos, ivec3 areaShift){
    ivec3 ret = (areaPos+(areaShift&1))+(AREA_SIZE>>1);
    areaPos-=ret&1;
    return ret>>1;
}

ivec3 uppperCascadeZonePos(ivec3 zonePos, ivec3 zoneShift, uint axis, float scale, out vec3 lightTravelAdj){
    zonePos+=zoneShift&1;
    zonePos.z+=int(axis&1u)-1;
    lightTravelAdj= scale* (vec3(zonePos&1)-0.5);
    return (zonePos>>1)+(AREA_SIZE>>2);
}


#define lightTravelScaleInv 2.0 //most voxels per block representable for lightTravel
#define lightTravelScale (1.0/lightTravelScaleInv);

//to consider: frexp, ldexp, bitfieldinsert, bitfieldextract

//similar accurracy to using float except I get to pick the scale
//according to graphing on desmos, these values work from just below 1e-4 to about 6.7e9
const float packScale = 128.0;
const int packBias = 1200;
#define NO_OCCLUSION 0xfu
#define FULL_OCCLUSION 0x800u
//uint packFloat12(float x){
//    if(x<=0)
//        return 0x80u;
//    int exponent = 0;
//    float sig = frexp(x,exponent);
//    sig = (sig-0.5)*30;
//    return uint((clamp(int(floor(sig)),0,15)<<8)|(clamp(exponent,-128,127)&0xff));
//}

//float unpackFloat12(uint x){
//    if(x==0x80u)
//        return 0;
//    int sig = (int(x)>>8)&0xf;
//    int exponent = int(x)&0xff;
//    return exponent==-128?0:ldexp(float(sig)/30.0+0.5,exponent);
//}

uint packOcclusionInfo(vec2 ray, uint map, float hitDist){
    uint packedHitDist = clamp(uint(round(hitDist*lightTravelScaleInv)),0u,0x3fu);
    return packUnorm4x8(vec4(0,0,ray)) | (packedHitDist<<4u) | (map);
}

uint setPackedOcclusionRayMap(uint occlusion, vec2 ray, uint map){
    return (occlusion&0xfff0u) | map | packUnorm4x8(vec4(0,0,ray));
}

uint packLightTravel(vec3 travel){
    ivec3 itravel = ivec3(round(travel*lightTravelScaleInv));
    itravel = clamp(itravel,ivec3(-63,-63,0),ivec3(63));
    itravel &= ivec3(0x7f,0x7f,0x3f);
    return (itravel.x<<25)|(itravel.y<<18)|(itravel.z<<12);
}

ivec3 intLightTravel(uint packedTravel){
    ivec3 itravel = ivec3(packedTravel&0xfe000000u,(packedTravel<<7)&0xfe000000u,(packedTravel<<13)&0x7e000000u);
    return itravel>>25;
}

vec3 unpackLightTravel(uint packedTravel){
    return intLightTravel(packedTravel)*lightTravelScale;
}

vec3 unpackLightTravel(PackedLight packedData){
    return unpackLightTravel(packedData.x);
}

vec3 unpackLightFilterColor(PackedLight packedData){
    return vec3(1.0);
//    return unpackUnorm4x8(packedData.z).yzw;
}

uint unpackLightEmission(PackedLight packedData){
    return (packedData.x>>6)&0xfu;
}

vec3 unpackLightColor(PackedLight packedData){
    return unpackLightFilterColor(packedData)*
    getLightIDColor(packedData.x&0x3fu)*(unpackLightEmission(packedData)/15.0);
}

float unpackOcclusionHitDist(uint occlusionInfo){
    return ((occlusionInfo>>4u)&0x3fu)*lightTravelScale;
}

uint unpackOcclusionMap(uint occlusionInfo){
    return occlusionInfo&0xfu;
}

uint unpackLightFlags(PackedLight packedData){
    return packedData.y&0xffu;
}

uint unpackLightAnimationType(PackedLight packedData){
    return blockLightAnimationType(packedData.x&0x3fu);
}

bool lightIsValid(PackedLight packedData){
    return bool(packedData.x&0x3fu);
}
vec2 unpackOcclusionRay(uint occlusionInfo){
    return unpackUnorm4x8(occlusionInfo).zw;
}

uint getLightStrength(PackedLight lightSrc){
    if(!lightIsValid(lightSrc))
        return 0;
    ivec3 travel = intLightTravel(lightSrc.x);
    vec3 color = unpackLightColor(lightSrc);
    float baseStrength = (color.x+color.y+color.b)/3.0;
//    float baseStrength = 1.0;

    #ifdef MC_SHAPED_LIGHT_FALLOFF
    vec3 displacement =max(abs(unpackLightTravel(lightSrc))-0.5,0);
    float strength = 2*max(0,baseStrength-(displacement.x+displacement.y+displacement.z)/15.0)/baseStrength;
    #else
    float lenSquared = float(dot(travel, travel)+1);
    float strength = (1+baseStrength)/lenSquared;
    #endif
    return uint(clamp(strength*1e7,0,1e9));
}

uint getPackedOcclusion(PackedLight packedData){
    return packedData.y;
}

void setPackedOcclusion(inout PackedLight packedData, uint occlusion){
    packedData.y=occlusion;
}

void setPackedLightTravel(inout PackedLight packedData, vec3 lightTravel){
    packedData.x=packLightTravel(lightTravel)|(packedData.x&0xfffu);
}

void setPackedLightColor(inout PackedLight packedData, vec3 color){
    packedData.z = packUnorm4x8(vec4(0,color)) | (packedData.z&0xffu);
}

void setPackedLightFlags(inout PackedLight packedData, uint flags){
    packedData.z = (packedData.z&0xffffff00u) | (flags&0xffu);
}

//float sunDist = 4+((frameCounter>>6)%10)*0.4;
#define SUN_DISTANCE 5
PackedLight packLightData(vec2 occlusionRay,uint occlusionMap,vec3 color,vec3 lightTravel,float occlusionHitDistance,uint emission, uint type,uint flags){
    PackedLight ret;
    ret.x = packLightTravel(lightTravel) | ((emission&0xfu)<<6) | (type&0x3fu);
    ret.y = packOcclusionInfo(occlusionRay, occlusionMap, occlusionHitDistance);
    ret.z = packUnorm4x8(vec4(0,color)) | (flags&0xffu);
    return ret;
}


//sampler/image access functions

#if defined SAMPLES_LIGHT_FACE || defined WRITES_LIGHT_FACE
#if DEBUG_SHOW_UPDATES>=0
layout(r8ui) uniform restrict uimage3D fsDebugMap;
#endif

layout (rgba32ui) uniform restrict
#ifndef WRITES_LIGHT_FACE
readonly
#endif
uimage3D fsVox;
#endif

#ifdef SAMPLES_LIGHT_FACE
PackedLight sampleLightData(ivec3 zonePos, ivec3 zoneShift, uint zoneMemOffset){
    return imageLoad(fsVox, toMemPos(zonePos,zoneShift,zoneMemOffset));
}
#endif


#ifdef WRITES_LIGHT_FACE
void setLightData(PackedLight light, ivec3 zonePos, ivec3 zoneShift, uint zoneMemOffset){
    ivec3 pos = toMemPos(zonePos,zoneShift,zoneMemOffset);
#if DEBUG_SHOW_UPDATES>=0
    imageStore(fsDebugMap,pos,uvec4(uint(frameCounter&0xff),0,0,0));
#endif
    imageStore(fsVox,pos,light);
}
#endif

uint bvec4ToUint(bvec4 b){
    return (uint(b.x)<<3u)|(uint(b.y)<<2u)|(uint(b.z)<<1u)|(uint(b.w));
}

vec4 ternary(uint conditions,vec4 ifTrue, vec4 ifFalse){
    return vec4(
        bool(conditions&8u)?ifTrue.x:ifFalse.x,
        bool(conditions&4u)?ifTrue.y:ifFalse.y,
        bool(conditions&2u)?ifTrue.z:ifFalse.z,
        bool(conditions&1u)?ifTrue.w:ifFalse.w
    );
}



//occlusion map stuff
bool isLit(vec3 position, vec2 occlRay, uint occlMap){
    return bool(occlMap & (abs(position.x)>occlRay.x*position.z?10u:5u) & (abs(position.y)>occlRay.y*position.z?12u:3u));
}



//outer x,y, inner xy
bool canIlluminateInBounds(vec4 edges, vec2 ray, uint occlusionMap){
    return bool( occlusionMap &
        ((uint(ray.x<edges.x)*10u)|(uint(ray.x>edges.z)*5u)) &
        ((uint(ray.y<edges.y)*12u)|(uint(ray.y>edges.w)*3u))
    );
}


bool sameLight(PackedLight a, PackedLight b){
    return a.xy==b.xy;
//    return !(bool((a.y^b.y)&0xffffffffu)||(bool((a.x^b.x)&0xffffffffu)));
}

//left, top, right, bottom
uint getLightEdges(uint map){
    uint xyww = (map&13u) | ((map&1u)<<1u);
    uint zxyz = (map>>1u) | ((map&2u)<<2u);
    return xyww&zxyz;
}

uint getOcclusionEdges(uint map){
    uint xyww = (map&13u) | ((map&1u)<<1u);
    uint zxyz = (map>>1u) | ((map&2u)<<2u);
    return 15u&~(xyww|zxyz);
}

uint getVariableCascadeLevel(uint frame, bool isAuxGroup){
#ifdef DOUBLE_PROC
    return isAuxGroup?0:getVariableCascadeLevel(frame);
#else
    return getVariableCascadeLevel(frame);
#endif
}

uint getVariableCascadeLevel(bool isAuxGroup){
    return getVariableCascadeLevel(frameCounter,isAuxGroup);
}
#endif