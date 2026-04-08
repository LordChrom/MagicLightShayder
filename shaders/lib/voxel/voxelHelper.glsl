#include "/lib/settings.glsl"

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

//input is is absolute world space, output is world space distance from center of voxel
vec3 subVoxelOffset(vec3 pos, float scale){
    return (fract(pos/scale)-0.5)*scale;
}

//works with either area pos or zone pos
ivec3 toMemPos(ivec3 pos, ivec3 spaceShift, uint memOffset){
    pos.x=(bool(pos.x&AREA_SIZE)?pos.x:((pos.x+spaceShift.x)&AREA_POS_MASK))+1;
    pos.y=(bool(pos.y&AREA_SIZE)?pos.y:((pos.y+spaceShift.y)&AREA_POS_MASK))+1;
    pos.z=(bool(pos.z&AREA_SIZE)?pos.z:((pos.z+spaceShift.z)&AREA_POS_MASK))+int(memOffset);
    return pos;
}



//Data packing/unpacking
struct areaMeta{//size 16
    ivec3 areaShift;
};

struct lightVoxData{
    vec2 occlusionRay;// ( |da/dL|, |db/dL| ), range [0,1], sign implicitly same as lightTravel.xy
    uint occlusionMap;//quadrants in which occlusion occurs, lit if true----> map.( x y )   ( +|a,b|  +|0,b| )
    vec3 color;                                                                  //( z w ) = ( +|b,0|  +|0,0| )
    vec3 lightTravel;//zone space. the displacement from the light source voxel center to the sample's voxel center
    float occlusionHitDistance; //distance from the light source to the edge which caused a shadow, for penumbra sharpness
    uint type;
    uint flags; //7 free, 1 for whether the light just had translucency applied
};

const lightVoxData noLight = {vec2(0),0u,vec3(0),vec3(0),0,0,0};

const float lightTravelScaleInv = 16.0; //most voxels per block representable for lightTravel
const float lightTravelScale = 1.0/lightTravelScaleInv;

//to consider: frexp and idexp

//bit layout of the packing
//x is 2x16 a,b of travel
//y is 1x16 occlusion hit distance, 1x16 z of travel
//z is 3x8 color, 8 free
//w 2x8 occlusion ray (b then a), 4x1 occlusion map, 1x4 light type, 8 free
lightVoxData unpackLightData(uvec4 packedData){
    lightVoxData ret;
    ret.lightTravel = vec3(ivec3(packedData.x,packedData.x<<16,packedData.y<<16)>>16)*lightTravelScale;
    ret.occlusionHitDistance=(packedData.y>>16)*lightTravelScale;

    vec4 colorEtc = unpackUnorm4x8(packedData.z);
    ret.color=colorEtc.xyz;
    ret.occlusionRay=unpackUnorm4x8(packedData.w).zw; //higher bits are later vec elements
    ret.occlusionMap = (packedData.w>>12)&0xfu;
    ret.type = (packedData.w>>8)&0xfu;
    ret.flags = packedData.w&0xffu;
    return ret;
}

uvec4 packLightData(lightVoxData data){
    uvec4 ret;
    uvec4 intTravel = ivec4(round(vec4(data.lightTravel,data.occlusionHitDistance)*lightTravelScaleInv));
//    uint intOcclMap =
//        (int(data.occlusionMap.x)<<15)|
//        (int(data.occlusionMap.y)<<14)|
//        (int(data.occlusionMap.z)<<13)|
//        (int(data.occlusionMap.w)<<12);

    ret.x = (intTravel.x<<16) | (intTravel.y&0xffffu);
    ret.y = (intTravel.w<<16) | (intTravel.z&0xffffu);
    ret.z = packUnorm4x8(vec4(data.color,0));
    ret.w = (packUnorm4x8(vec4(0,0,data.occlusionRay))&0xffff0000u) | ((data.occlusionMap&0xfu)<<12) | ((data.type&0xfu)<<8) | (data.flags&0xffu);
    return ret;
}

uvec4 unpackBytes(uint packedData){
    return uvec4(packedData>>24,packedData>>16,packedData>>8,packedData)&0xffu;
}

uint packBytes(uvec4 data){
    return ((data.x<<24)|(data.y<<16))|((data.z<<8)|(data.w));
}

uvec4 unpackWorldVox(uint packedData){
    uvec4 ret = uvec4((packedData>>14),(packedData>>7)&0x7fu,packedData&0x7fu,packedData>>21);
    ret.rgb<<=1;
    return ret;
}

uint packWorldVox(uvec4 data){
    data.rgb=(data.rgb>>=1)&0x7fu;
    return ((data.w<<21)|(data.x<<14))|((data.y<<7)|(data.z));
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

void setLightData(lightVoxData light, ivec3 zonePos, ivec3 zoneShift, uint zoneMemOffset){
#if DEBUG_SHOW_UPDATES>=0
    for(int layer = 0; layer<VOX_LAYERS; layer++){
        uint frameIndicator = (frameCounter&0x3f);
        light.flags=(light.flags&3u) | (frameIndicator<<2);
    }
#endif
    imageStore(lightVox,toMemPos(zonePos,zoneShift,zoneMemOffset),packLightData(light));
}
#endif


#ifdef SAMPLES_VOX
uniform usampler3D worldVoxSampler;

uint getRawVoxData(ivec3 areaPos, ivec3 areaShift, uint areaMemOffset){
    return texelFetch(worldVoxSampler,toMemPos(areaPos,areaShift,areaMemOffset),0).x;
}

uvec4 getVoxData(ivec3 areaPos, ivec3 areaShift, uint areaMemOffset){
    return unpackWorldVox(getRawVoxData(areaPos,areaShift,areaMemOffset));
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
//bvec4
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
float penumbralLightTest(vec3 position, lightVoxData light){
    float width =(PENUMBRA_WIDTH)*((position.z/light.occlusionHitDistance)-1);

    vec2 m = clamp((abs(position.xy/position.z)-light.occlusionRay)/width,-0.5,0.5);

    vec4 mix = max(vec2(0.5+m.x,0.5-m.x),0).xyxy * max(vec2(0.5+m.y,0.5-m.y),0).xxyy;
    mix*=1u&uvec4(light.occlusionMap>>3, light.occlusionMap>>2, light.occlusionMap>>1, light.occlusionMap);

    return mix.x+mix.y+mix.z+mix.w;
}
#endif



//outer x,y, inner xy
bool canIlluminateInBounds(vec4 edges, vec2 ray, uint occlusionMap){
    return bool( occlusionMap &
        ((int(ray.x<edges.x)*10u)|(int(ray.x>edges.z)*5u)) &
        ((int(ray.y<edges.y)*12u)|(int(ray.y>edges.w)*3u))
    );
}



//misc
bool sameLight(lightVoxData a, lightVoxData b){
    return (a.color==b.color) && (a.lightTravel==b.lightTravel) && (a.type==b.type) || (a.type==1 && b.type==1);
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

