#ifndef VOXEL_HELPER
#define VOXEL_HELPER
#include "/lib/settings.glsl"

uniform vec3 globalOrigin, previousGlobalOrigin;
uniform int frameCounter;

//caps out at 31 but its whatever
uint countTrailingZeroes(uint x){
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

vec3 getGlobalOrigin(float scale){
    return floor(globalOrigin/scale)*scale;
}
vec3 getPreviousGlobalOrigin(float scale){
    return floor(previousGlobalOrigin/scale)*scale;
}
ivec3 getAreaShift(float scale, vec3 origin){
    return ivec3(floor(origin/scale));
}
ivec3 getAreaShift(float scale){return getAreaShift(scale,getGlobalOrigin(scale));}
ivec3 getPreviousAreaShift(float scale){return getAreaShift(scale,getPreviousGlobalOrigin(scale));}

ivec3 getFloodShift(){
    return ivec3(floor(globalOrigin));
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



//Data packing/unpacking
struct areaMeta{//size 16
    ivec3 areaShift;
};


#define lightTravelScaleInv 8.0 //most voxels per block representable for lightTravel
#define lightTravelScale (1.0/lightTravelScaleInv);

//to consider: frexp, ldexp, bitfieldinsert, bitfieldextract

//similar accurracy to using float except I get to pick the scale
//according to graphing on desmos, these values work from just below 1e-4 to about 6.7e9
const float packScale = 128.0;
const int packBias = 1200;
#define NO_OCCLUSION 0x80fu
#define FULL_OCCLUSION 0x800u
uint packFloat12(float x){
    if(x<=0)
        return 0x80u;
    int exponent = 0;
    float sig = frexp(x,exponent);
    sig = (sig-0.5)*30;
    return uint((clamp(int(floor(sig)),0,15)<<8)|(clamp(exponent,-128,127)&0xff));
}

//TODO investigate if ldexp/frexp is actually fast
float unpackFloat12(uint x){
    if(x==0x80u)
        return 0;
    int sig = (int(x)>>8)&0xf;
    int exponent = int(x)&0xff;
    return exponent==-128?0:ldexp(float(sig)/30.0+0.5,exponent);
}

uint packOcclusionInfo(vec2 ray, uint map, float hitDist){
    return (packUnorm4x8(vec4(0,0,ray))) | (packFloat12(hitDist)<<4u) | (map);
}

uint packLightTravel(vec3 travel){
    ivec3 itravel = ivec3(round(travel*lightTravelScaleInv));
    itravel = clamp(itravel,ivec3(-255,-255,0),ivec3(255));
    itravel &= ivec3(0x1ff,0x1ff,0xff);
    return (itravel.x<<23)|(itravel.y<<14)|(itravel.z<<6);
}

ivec3 intLightTravel(uint packedTravel){
    ivec3 itravel = ivec3(packedTravel&0xff800000u,(packedTravel<<9)&0xff800000u,(packedTravel<<17)&0x7f800000u);
    return itravel>>23;
}

vec3 unpackLightTravel(uint packedTravel){
    return intLightTravel(packedTravel)*lightTravelScale;
}

vec3 unpackLightTravel(uvec4 packedData){
    return unpackLightTravel(packedData.x);
}

vec3 unpackLightColor(uvec4 packedData){
    return unpackUnorm4x8(packedData.y).yzw;
}

float unpackOcclusionHitDist(uint occlusionInfo){
    return unpackFloat12((occlusionInfo>>4u)&0xfffu);
}

uint unpackOcclusionMap(uint occlusionInfo){
    return occlusionInfo&0xfu;
}

uint unpackLightFlags(uvec4 packedData){
    return packedData.y&0xffu;
}

uint unpackLightType(uvec4 packedData){
    return (packedData.x)&0xfu;
}

vec2 unpackOcclusionRay(uint occlusionInfo){
    return unpackUnorm4x8(occlusionInfo).zw;
}

uint getLightStrength(uvec4 lightSrc){
    uint type = unpackLightType(lightSrc);
    if(type==LIGHT_TYPE_SUN)
        return 0xffffff00;
    if(type==0)
        return 0;
    ivec3 travel = intLightTravel(lightSrc.x);
    #ifdef MC_SHAPED_LIGHT_FALLOFF
    vec3 displacement =max(abs(unpackLightTravel(lightSrc))-0.5,0);

    vec3 a = unpackLightColor(lightSrc);
    float base = (a.x+a.y+a.b)/3.0;
    float strength = 2*max(0,base-(displacement.x+displacement.y+displacement.z)/15.0)/base;
    #else
    float lenSquared = float(dot(travel, travel)+1);
    float strength = (1+length(unpackLightColor(lightSrc)))/lenSquared;
    #endif
    return uint(clamp(strength*1e7,0,1e9));
}

uint getPackedOcclusion(uvec4 packedData){
    return packedData.z;
}

void setPackedOcclusion(inout uvec4 packedData, uint occlusion){
    packedData.z=occlusion;
}

void setPackedLightTravel(inout uvec4 packedData, vec3 lightTravel){
    packedData.x=packLightTravel(lightTravel)|(packedData.x&0x3fu);
}

void setPackedLightColor(inout uvec4 packedData, vec3 color){
    packedData.y = packUnorm4x8(vec4(0,color)) | (packedData.y&0xffu);
}

void setPackedLightFlags(inout uvec4 packedData, uint flags){
    packedData.y = (packedData.y&0xffffff00u) | (flags&0xffu);
}

//float sunDist = 4+((frameCounter>>6)%10)*0.4;
#define SUN_DISTANCE 5
uvec4 packLightData(vec2 occlusionRay,uint occlusionMap,vec3 color,vec3 lightTravel,float occlusionHitDistance,uint type,uint flags){
    uvec4 ret;
    if(type==LIGHT_TYPE_SUN)
        lightTravel.z=SUN_DISTANCE;
    ret.x = packLightTravel(lightTravel) | (type&0xfu);
    ret.y = packUnorm4x8(vec4(0,color)) | (flags&0xffu);
    ret.z = packOcclusionInfo(occlusionRay, occlusionMap, occlusionHitDistance);
    return ret;
}

uvec4 unpackWorldVox(uint packedData){
    uvec4 ret = uvec4((packedData>>14u)&0x7fu,(packedData>>7u)&0x7fu,packedData&0x7fu,packedData>>21u);
    ret.rgb<<=1;
    return ret;
}

uint packWorldVox(vec3 color, uint metadata){
    uvec3 intColor = uvec3(color*9.0+0.5);
    return (metadata<<WORLDVOX_META_SHIFT)|((intColor.r<<8u))|((intColor.g<<4u)|(intColor.b));
}

vec3 worldVoxColor(uint packedData){
    return vec3(uvec3(packedData>>8u,packedData>>4u,packedData)&0xfu)/9.0;
}


//sampler/image access functions

#if defined SAMPLES_LIGHT_FACE || defined WRITES_LIGHT_FACE
layout (rgba32ui) uniform restrict
#ifndef WRITES_LIGHT_FACE
readonly
#endif
uimage3D lightVox;
#endif

#ifdef SAMPLES_LIGHT_FACE
uvec4 sampleLightData(ivec3 zonePos, ivec3 zoneShift, uint zoneMemOffset){
    return imageLoad(lightVox, toMemPos(zonePos,zoneShift,zoneMemOffset));
}
#endif


#ifdef WRITES_LIGHT_FACE
void setLightData(uvec4 light, ivec3 zonePos, ivec3 zoneShift, uint zoneMemOffset){
#if DEBUG_SHOW_UPDATES>=0
    for(int layer = 0; layer<VOX_LAYERS; layer++){
        uint frameIndicator = uint(frameCounter&0x3f);
        setPackedLightFlags(light,(unpackLightFlags(light)&3u) | (frameIndicator<<2u));
    }
#endif
    imageStore(lightVox,toMemPos(zonePos,zoneShift,zoneMemOffset),light);
}
#endif


#if defined SAMPLES_VOX || defined WRITES_VOX
layout (r32ui) uniform restrict
#ifndef WRITES_VOX
readonly
#endif
uimage3D worldVox;
#endif

#ifdef SAMPLES_VOX
//uniform usampler3D worldVoxSampler;

uint getVoxData(ivec3 areaPos, ivec3 areaShift, uint areaMemOffset){
    ivec3 memPos = toMemPos(areaPos,areaShift,areaMemOffset);
//    return texelFetch(worldVoxSampler,memPos,0).x;
    return imageLoad(worldVox,memPos).x;
}
#endif


#ifdef WRITES_VOX
//doesnt reset timer
void updateVoxData(uint packedData, ivec3 areaPos, ivec3 areaShift, uint areaMemOffset){
    ivec3 memPos = toMemPos(areaPos,areaShift,areaMemOffset);
    imageAtomicMax(worldVox,memPos,packedData);
}

void setVoxData(uint packedData, ivec3 areaPos, ivec3 areaShift, uint areaMemOffset){
    ivec3 memPos = toMemPos(areaPos,areaShift,areaMemOffset);
    imageStore(worldVox,memPos,uvec4(packedData,0,0,0));
}
#endif


#if defined SAMPLES_OBSTRUCTION || defined WRITES_OBSTRUCTION
layout (r32ui) uniform restrict
#ifndef WRITES_VOX
readonly
#endif
uimage3D obstructionVox;
#endif

#ifdef SAMPLES_OBSTRUCTION
uint getObstructionData(ivec3 areaPos, ivec3 areaShift, uint areaMemOffset){
    ivec3 memPos = toMemPos(areaPos,areaShift,areaMemOffset);
    return imageLoad(obstructionVox,memPos).x;
}
#endif


#ifdef WRITES_OBSTRUCTION
void submitObstructionData(uint obstruction, ivec3 areaPos, ivec3 areaShift, uint areaMemOffset){
    ivec3 memPos = toMemPos(areaPos,areaShift,areaMemOffset);
    imageAtomicOr(obstructionVox,memPos,obstruction);
}
#endif


#ifdef SAMPLES_FLOOD
uniform sampler3D floodfillSampler;

vec4 getFloodData(ivec3 areaPos, ivec3 areaShift){
    return texelFetch(floodfillSampler,modFloodfillSize(areaPos+areaShift),0);
}

vec4 sampleFloodData(vec3 worldPos){
    vec3 distFromCenter = worldPos-globalOrigin;
    distFromCenter=abs(distFromCenter);
    if(max(max(distFromCenter.x,distFromCenter.y),distFromCenter.z)>0.5*(FLOODFILL_SIZE-1))
        return vec4(0);

    vec3 texPosition = fract((worldPos/FLOODFILL_SIZE)+0.5);
    const float edgeMargin = 0.5/FLOODFILL_SIZE;
    const float topEdgeMargin = 1-edgeMargin;

    if(!(texPosition.x<edgeMargin || texPosition.y<edgeMargin || texPosition.z<edgeMargin ||
        texPosition.x>topEdgeMargin || texPosition.y>topEdgeMargin || texPosition.z>topEdgeMargin)
    ){
        return texture(floodfillSampler,texPosition);
    }

    ivec3 lowerPos = ivec3(floor(worldPos-0.5))+FLOODFILL_SIZE/2;
    ivec3 upperPos = modFloodfillSize(lowerPos+1);
    lowerPos = modFloodfillSize(lowerPos);
    worldPos=fract(worldPos+0.5);
    vec4 ret;
    for(int x=0;x<=1;x++){
        for(int y=0;y<=1;y++){
            for(int z=0;z<=1;z++){
                ivec3 pos = ivec3(x,y,z);
                vec3 weight = pos+worldPos*(1-2*pos);
                pos = pos*lowerPos+(1-pos)*upperPos;
                ret+=texelFetch(floodfillSampler,pos,0)*(weight.x*weight.y*weight.z);
            }
        }
    }
    return ret;
}
#endif


#ifdef WRITES_FLOOD
layout (rgba8) uniform writeonly restrict image3D floodfillVox;

void setFloodData(vec4 data, ivec3 areaPos, ivec3 areaShift){
    imageStore(floodfillVox,modFloodfillSize(areaPos+areaShift),data);
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

// x is 2x9 a,b of travel, 1x8 L of travel, 2 free, 1x4 light type
// y is 3x8 color, 8 flags
bool sameLight(uvec4 a, uvec4 b){
    bool sameColor = !bool((a.y^b.y)&0xffffff00u);

    return sameColor && (
        (a.x==b.x)
        || (unpackLightType(a)==LIGHT_TYPE_SUN && unpackLightType(b) == LIGHT_TYPE_SUN)
    );
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


//TODO ssbo?
uniform float sunAngle;
uvec4 getSunlight(uint axis){
    if(sunAngle>=0.5 || ((axis&6u)==4u))
        return uvec4(0);
    float angleOfTheSun = sunAngle*2*PI;
    vec3 sunLightTravel = normalize(vec3(-cos(angleOfTheSun),sin(angleOfTheSun),0));
    sunLightTravel = areaToZoneSpaceRelative(sunLightTravel,axis);
//    if(sunLightTravel.z<=1e-4)
//        return uvec4(0);

    sunLightTravel*=-sign(sunLightTravel.z)*(SUN_DISTANCE/max(abs(sunLightTravel.z),0.001));
    if(-sunLightTravel.z<max(abs(sunLightTravel.x),abs(sunLightTravel.y)))
        return uvec4(0);
    return packLightData(vec2(0),0xfu,vec3(242,242,242)/255,sunLightTravel,0f,1,0xfeu);
}
#endif