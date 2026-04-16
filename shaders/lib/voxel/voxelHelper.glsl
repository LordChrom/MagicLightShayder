#include "/lib/settings.glsl"

uniform vec3 globalOrigin, previousGlobalOrigin;
uniform int frameCounter;
uniform bool hasCeiling;

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




const mat3[] areaToZoneSpaceMats = {
mat3(0,1,0, 0,0,1, -1,0,0),
mat3(0,1,0, 0,0,1, 1,0,0),

mat3(0,0,1, 1,0,0, 0,-1,0),
mat3(0,0,1, 1,0,0, 0,1,0),

mat3(1,0,0,  0,1,0,  0,0,-1),
mat3(1,0,0,  0,1,0,  0,0,1)
};

//in order from 0 to 5, -x,+x,-y,+y,-z,+z
ivec3 axisNumToVec(uint axis){
    mat3 convMat = areaToZoneSpaceMats[axis];
    return ivec3(convMat[0].z,convMat[1].z,convMat[2].z);
}

//output.xyz is area xyz
ivec3 worldPosToArea(vec3 pos, float scale){
    pos -= getGlobalOrigin(scale);
    pos = floor(pos/scale+(AREA_SIZE*0.5));
    return ivec3(pos);
}

uint getCascadeLevel(vec3 worldPos){
    worldPos-=globalOrigin;
    worldPos = abs(worldPos/(0.25*MIN_SCALE*AREA_SIZE));
    float maxDist = max(max(worldPos.x,worldPos.y),worldPos.z);
    return uint(max(0,floor(log2(maxDist))));
}

uint getCascadeLevel(vec3 worldPos, vec3 normal){
    return getCascadeLevel(worldPos+0.1*normal);
}

float getScale(uint cascadeLevel){
    return MIN_SCALE*float(1<<cascadeLevel);
}

bool isVoxelInBounds(vec3 worldPos){
    const float maxDist = 0.5*AREA_SIZE*MIN_SCALE*(1<<(NUM_CASCADES-1));
    worldPos = abs(worldPos-getGlobalOrigin(MAX_SCALE));
    return (worldPos.x<=maxDist) && (worldPos.y<=maxDist) && (worldPos.z<=maxDist);
}

uint zoneOffset(uint axis, uint layer, uint cascadeLevel){
    return 1+int((ZONE_OFFSET)*(VOX_LAYERS*axis+layer+(6*VOX_LAYERS)*cascadeLevel));
}

uint areaOffset(uint cascadeLevel){
    return 1+AREA_OFFSET*cascadeLevel;
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

#if (AREA_SIZE&(AREA_SIZE-1))
    pos = ivec3(uvec3(pos+0x100000u)%AREA_SIZE); //TODO make faster, gets called a lot
#else
    pos&=(AREA_SIZE-1);
#endif
    pos.z+=int(memOffset);
    return pos;
}

ivec3 upperCascadeAreaPos(ivec3 areaPos, ivec3 areaShift){
    return ((areaPos+(areaShift&1))>>1)+(AREA_SIZE>>2);
}

ivec3 uppperCascadeZonePos(ivec3 zonePos, ivec3 zoneShift, uint axis, float scale, out vec3 lightTravelAdj){
    zonePos+=zoneShift&1;
//    zonePos.z+=i;
    zonePos.z+=int(axis&1u)-1;

    lightTravelAdj= scale* (vec3(zonePos&1)-0.5);
//    lightTravelAdj.z-=scale;
    return (zonePos>>1)+(AREA_SIZE>>2);
}



//Data packing/unpacking
struct areaMeta{//size 16
    ivec3 areaShift;
};


const float lightTravelScaleInv = 16.0; //most voxels per block representable for lightTravel
const float lightTravelScale = 1.0/lightTravelScaleInv;

//to consider: frexp, ldexp, bitfieldinsert, bitfieldextract

//similar accurracy to using float except I get to pick the scale
//according to graphing on desmos, these values work from just below 1e-4 to about 6.7e9
const float packScale = 128.0;
const int packBias = 1200;
#define NO_OCCLUSION 0x80fu
uint packFloat12(float x){
    if(x<=0)
        return 0x80u;
    int exponent = 0;
    float sig = frexp(x,exponent);
    sig = (sig-0.5)*30;
    return (clamp(int(floor(sig)),0,15)<<8)|(clamp(exponent,-128,127)&0xff);
}

float unpackFloat12(uint x){
    if(x==0x80u)
        return 0;
    int sig = (int(x)>>8)&0xf;
    int exponent = int(x)&0xff;
    return exponent==-128?0:ldexp(float(sig)/30.0+0.5,exponent);
}

uint packOcclusionInfo(vec2 ray, uint map, float hitDist){
    return (packUnorm4x8(vec4(0,0,ray))) | (packFloat12(hitDist)<<4) | (map);
}

vec3 unpackLightColor(uvec4 packedData){
    return unpackUnorm4x8(packedData.z).yzw;
}

vec3 unpackLightTravel(uvec4 packedData){
    return vec3(ivec3(packedData.x,packedData.x<<16,packedData.y<<16)>>16)*lightTravelScale;
}

float unpackOcclusionHitDist(uint occlusionInfo){
    return unpackFloat12((occlusionInfo>>4)&0xfffu);
}

uint unpackOcclusionMap(uint occlusionInfo){
    return occlusionInfo&0xfu;
}

uint unpackLightFlags(uvec4 packedData){
    return packedData.z&0xffu;
}

uint unpackLightType(uvec4 packedData){
    return (packedData.y>>16)&0xfu;
}

vec2 unpackOcclusionRay(uint occlusionInfo){
    return unpackUnorm4x8(occlusionInfo).zw;
}

void setPackedLightTravel(inout uvec4 packedData, vec3 travel){
    uvec3 intTravel = ivec3(round(travel*lightTravelScaleInv));

    packedData.x = (intTravel.x<<16) | (intTravel.y&0xffffu);
    packedData.y = (packedData.y&0xffff0000u) | (intTravel.z&0xffffu);
}

void setPackedLightColor(inout uvec4 packedData, vec3 color){
    packedData.z = packUnorm4x8(vec4(0,color)) | (packedData.z&0xffu);
}

void setPackedLightFlags(inout uvec4 packedData, uint flags){
    packedData.z = (packedData.z&0xffffff00u) | (flags&0xffu);
}

uvec4 packLightData(vec2 occlusionRay,uint occlusionMap,vec3 color,vec3 lightTravel,float occlusionHitDistance,uint type,uint flags){
    uvec4 ret;
    uvec3 intTravel = ivec3(round(lightTravel*lightTravelScaleInv));

    ret.x = (intTravel.x<<16) | (intTravel.y&0xffffu);
    ret.y = ((type&0xfu)<<16) | (intTravel.z&0xffffu);
    ret.z = packUnorm4x8(vec4(0,color)) | (flags&0xffu);
    ret.w = packOcclusionInfo(occlusionRay, occlusionMap, occlusionHitDistance);
    return ret;
}

uvec4 unpackBytes(uint packedData){
    return uvec4(packedData>>24,packedData>>16,packedData>>8,packedData)&0xffu;
}

uint packBytes(uvec4 data){
    return ((data.x<<24)|(data.y<<16))|((data.z<<8)|(data.w));
}

uvec4 unpackWorldVox(uint packedData){
    uvec4 ret = uvec4((packedData>>14)&0x7fu,(packedData>>7)&0x7fu,packedData&0x7fu,packedData>>21);
    ret.rgb<<=1;
    return ret;
}

uint packWorldVox(uvec4 data){
    data.rgb=(data.rgb>>=1)&0x7fu;
    return ((data.w<<21)|(data.x<<14))|((data.y<<7)|(data.z));
}

vec3 worldVoxColor(uint packedData){
    return vec3(uvec3(packedData>>14,packedData>>7,packedData)&0x7fu)*1.0/127;
}


//sampler/image access functions
#ifdef SAMPLES_LIGHT_FACE
uniform usampler3D lightVoxSampler;

uvec4 sampleLightData(ivec3 zonePos, ivec3 zoneShift, uint zoneMemOffset){
    return texelFetch(lightVoxSampler, toMemPos(zonePos,zoneShift,zoneMemOffset),0);
}
#endif


#ifdef WRITES_LIGHT_FACE
layout (rgba32ui) uniform writeonly restrict uimage3D lightVox;

void setLightData(uvec4 light, ivec3 zonePos, ivec3 zoneShift, uint zoneMemOffset){
#if DEBUG_SHOW_UPDATES>=0
    for(int layer = 0; layer<VOX_LAYERS; layer++){
        uint frameIndicator = (frameCounter&0x3f);
        setPackedLightFlags(light,(unpackLightFlags(light)&3u) | (frameIndicator<<2));
    }
#endif
    imageStore(lightVox,toMemPos(zonePos,zoneShift,zoneMemOffset),light);
}
#endif


#ifdef SAMPLES_VOX
uniform usampler3D worldVoxSampler;

uint getVoxData(ivec3 areaPos, ivec3 areaShift, uint areaMemOffset){
    return texelFetch(worldVoxSampler,toMemPos(areaPos,areaShift,areaMemOffset),0).x;
}
#endif


#ifdef WRITES_VOX
layout (r32ui) uniform restrict uimage3D worldVox;

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

#ifdef PENUMBRAS_ENABLED
float penumbralLightTest(vec3 position, vec2 ray, uint map, float occlHitDist){
    float width =(PENUMBRA_WIDTH)*((position.z/occlHitDist)-1);

    vec2 m = clamp((abs(position.xy/position.z)-ray)/width+0.5,0,1);

    vec2 mixX = mix(
        vec2(1u&(map>>0),1u&(map>>2)),
        vec2(1u&(map>>1),1u&(map>>3)),
    m.x);
    return mix(mixX.x,mixX.y,m.y);
}
#endif



//outer x,y, inner xy
bool canIlluminateInBounds(vec4 edges, vec2 ray, uint occlusionMap){
    return bool( occlusionMap &
        ((int(ray.x<edges.x)*10u)|(int(ray.x>edges.z)*5u)) &
        ((int(ray.y<edges.y)*12u)|(int(ray.y>edges.w)*3u))
    );
}

//- - x is 2x16 a,b of travel
//- - y is 12 free, 1x4 light type, 1x16 z of travel
//- - z is 3x8 color, 8 flags
bool sameLight(uvec4 a, uvec4 b){
    return (((a.xyz^b.xyz)&uvec3(0xffffffff,0x000fffffu,0xffffff00u))==uvec3(0))
        || (unpackLightType(a)==LIGHT_TYPE_SUN && unpackLightType(b) == LIGHT_TYPE_SUN);
}

//left, top, right, bottom
uint getLightEdges(uint map){
    uint xyww = (map&13u) | ((map&1u)<<1);
    uint zxyz = (map>>1) | ((map&2u)<<2);
    return xyww&zxyz;
}

uint getOcclusionEdges(uint map){
    uint xyww = (map&13u) | ((map&1u)<<1);
    uint zxyz = (map>>1) | ((map&2u)<<2);
    return 15u&~(xyww|zxyz);
}

//caps out at 31 but its whatever
uint countTrailingZeroes(uint x){
    uint ret = 0;
    for(uint bits = 16; bits>=2; bits>>=1){
        bool bitsInLowerHalf = bool(x&((1u<<bits)-1));
        ret=bitsInLowerHalf?ret:ret+bits;
        x  =bitsInLowerHalf?x:x>>bits;
    }
    ret+=((~x)&0x1u);
    return ret;
}

uint getVariableCascadeLevel(int frame){
    uint trailingZeroes = countTrailingZeroes(frame);
#ifdef DOUBLE_PROC
    return trailingZeroes+1;
#else
    return trailingZeroes;
#endif
}

bool evenVisit(uint cascadeLevel);


uint getVariableCascadeLevel(int frame, bool isAuxGroup){
#ifdef DOUBLE_PROC
    return isAuxGroup?0:getVariableCascadeLevel(frame);
#else
    return getVariableCascadeLevel(frame);
#endif
}

uint getVariableCascadeLevel(bool isAuxGroup){
    return getVariableCascadeLevel(frameCounter,isAuxGroup);
}

const vec3 sunColor = vec3(242,242,242)/255;
const vec3 sunPos = vec3(0,0,1000);
const uvec4 noLight = uvec4(0);
uvec4 defaultSunLight = packLightData(vec2(0),0xfu,sunColor,vec3(0,0,10),0f,1,0xfeu);