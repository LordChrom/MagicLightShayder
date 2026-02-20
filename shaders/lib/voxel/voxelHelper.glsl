#include "/lib/settings.glsl"

#define SECTION_WIDTH 16
#define SECTION_DEPTH 16
#define UPDATE_STRIDE 2


//TODO: test split sampler+writeonly uimage vs combined image
#ifdef READS_LIGHT_FACE
uniform usampler3D lightVoxSampler;
#endif

#ifdef WRITES_LIGHT_FACE
layout (rgba32ui) uniform writeonly restrict uimage3D lightVox;
#endif

#ifdef READS_VOX
layout (rgba8ui) uniform readonly restrict uimage3D worldVox;
#endif

#ifdef WRITES_VOX
layout (rgba8ui) uniform writeonly restrict uimage3D worldVox;
#endif


//axes for voxel faces are represented as a,b,L, with L being the direction light travels in, a being the axis after it,
//and b being the one after that. all examples are xyz,xy-z, zxy, zx-y, yzx,yz-x. Handedness be damned idc.
struct lightVoxData{
    vec2 occlusionRay;// ( |da/dL|, |db/dL| )                                ( x y )   ( +|a,b|  +|0,b| )
    bvec4 occlusionMap;//quadrants in which occlusion occurs, lit if true -> ( z w ) = ( +|b,0|  +|0,0| )
    vec3 color;
    uint emission;//blocklight strength. Potentially redundant w/ color.
    vec3 lightTravel;//the displacement from the light source voxel center to the sample's voxel center
};


const float lightTravelScaleInv = 16.0; //most voxels per block representable for lightTravel
const float lightTravelScale = 1.0/lightTravelScaleInv;

const lightVoxData noLight = {vec2(0),bvec4(false),vec3(0),0,vec3(0)};

bool isVoxelInBounds(vec3 worldPos){
    return worldPos.x>=0 && worldPos.y>=0 && worldPos.z>=0 && worldPos.x<16 && worldPos.y<16 && worldPos.z<16;
}


const mat3[] worldToSectionSpaceMats = {
mat3(0,1,0, 0,0,1, -1,0,0),
mat3(0,1,0, 0,0,1, 1,0,0),

mat3(0,0,1, 1,0,0, 0,-1,0),
mat3(0,0,1, 1,0,0, 0,1,0),

mat3(1,0,0,  0,1,0,  0,0,-1),
mat3(1,0,0,  0,1,0,  0,0,1)
};

//in order from 0 to 5, -x,+x,-y,+y,-z,+z
//lsb is 0=neg,1=pos
//returns 0,0,0 when axis out of range
ivec3 axisNumToVec(uint axis){
//    uint upper = axis>>1u;
//    return ivec3(upper==0,upper==1,upper==2)*(((int(axis)&1)<<1)-1);
    return ivec3(worldToSectionSpaceMats[axis]*vec3(0,0,1));
}



//xyz is section xyz
//w is section number
ivec4 worldPosToSection(vec3 pos, float scale){
    return ivec4(ivec3(round(pos/scale+0.5)*scale),0);
}

ivec3 sectionToFaceSpace(ivec4 sectionPos, uint axis){
    uint upper = axis>>1u;
    ivec3 ret = sectionPos.xyz;
    switch(upper){
        case 0u:
            ret=sectionPos.yzx;
            break;
        case 1u:
            ret=sectionPos.zxy;
            break;
        case 2u:
            ret=sectionPos.xyz;
            break;
        default:
            ret=ivec3(0);
            break;
    }

    if((axis&1u)==0u){
        ret.z=15-ret.z;
    }

    ret.z+=int(20*axis); //TODO fix overlap

    return ret;
}

vec3 subVoxelOffset(vec3 pos, float scale){
    return (fract(pos/scale)-0.5)*scale;
}



//to consider: frexp and idexp

//bit layout of the packing
//x is 2x16 a,b of travel
//y is 2x8 occlusion (b then a), 1x16 z of travel
//z is 3x8 color, 1x4 occlusion map, 1x4 emissive strength,
//w is all free! Yay! Could save memory but will likely use for more more features later
lightVoxData unpackLightData(uvec4 packedData){
    lightVoxData ret;
    ret.lightTravel = vec3(ivec3(packedData.x,packedData.x<<16,packedData.y<<16)>>16)*lightTravelScale;
    ret.emission = packedData.z&0xfu;
    ret.occlusionMap = bvec4(packedData.z&0x80u,packedData.z&0x40u,packedData.z&0x20u,packedData.z&0x10u);
    ret.color=unpackUnorm4x8(packedData.z).yzw;
    ret.occlusionRay=unpackUnorm4x8(packedData.y).zw; //higher bits are later vec elements
    return ret;
}

uvec4 packLightData(lightVoxData data){
    uvec4 ret;
    uvec3 intTravel = ivec3(round(data.lightTravel*lightTravelScaleInv));
    uvec4 intOcclMap = uvec4(data.occlusionMap)<<uvec4(7,6,5,4);

    ret.x = (intTravel.x<<16) | (0xffffu&intTravel.y);
    ret.y = intTravel.z | (packUnorm4x8(vec4(0,0,data.occlusionRay))&0xffff0000u);
    ret.z = (0xffffff00u&packUnorm4x8(vec4(0,data.color))) | (data.emission&0xfu)
            | (0xf0u&((intOcclMap.x|intOcclMap.y)|(intOcclMap.z|intOcclMap.w)));
    ret.w = 0;
    return ret;
}



bool isLit(vec3 position, vec2 ray, bvec4 map){
    vec2 slope = abs(position.xy/position.z);
    ivec2 pos = ivec2(int(slope.x>ray.x),int(slope.y>ray.y));
    return map[3-pos.x-(pos.y<<1)] && (slope.x<=1) && (slope.y<=1);
}

bool isLit(vec3 position, lightVoxData light){
    return isLit(position,light.occlusionRay,light.occlusionMap);
}

bvec4 and(bvec4 a, bvec4 b){return bvec4(a.x&&b.x,a.y&&b.y,a.z&&b.z,a.w&&b.w);}
bvec4 or(bvec4 a, bvec4 b){return bvec4(a.x||b.x,a.y||b.y,a.z||b.z,a.w||b.w);}
bvec4 not(bvec4 a){return bvec4(!a.x,!a.y,!a.z,!a.w);}

//left, top, right, bottom
bvec4 getOcclusionEdges(bvec4 occlusionMap){
    return not(or(occlusionMap.zxyw,occlusionMap.xywz));
}

vec4 conditional(vec4 vec, bvec4 conditions){
    return vec4(
        vec.x*int(conditions.x),
        vec.y*int(conditions.y),
        vec.z*int(conditions.z),
        vec.w*int(conditions.w)
    );
}

vec4 ternary(bvec4 conditions,vec4 ifTrue, vec4 ifFalse){
    ivec4 tmp = ivec4(conditions);
    return ifTrue*tmp+(1-tmp)*ifFalse;
}



#ifdef READS_LIGHT_FACE
lightVoxData getLightData(ivec3 texelCoord){
    return unpackLightData(texelFetch(lightVoxSampler, texelCoord,0));
}
lightVoxData getLightData(ivec4 sectionPos, uint axis){
    ivec3 texelCoord = sectionToFaceSpace(sectionPos,axis);
    return getLightData(texelCoord);
}
#endif

#ifdef WRITES_LIGHT_FACE
void setLightData(lightVoxData light, ivec3 texelCoord){
    imageStore(lightVox,texelCoord, packLightData(light));
}
void setLightData(lightVoxData light, ivec4 sectionPos, uint axis){
    ivec3 texelCoord = sectionToFaceSpace(sectionPos,axis);
    setLightData(light,texelCoord);
}
#endif

#ifdef READS_VOX
uvec4 getVoxData(ivec3 texelCoord){
    return imageLoad(worldVox,texelCoord);
}
#endif

#ifdef WRITES_VOX
void setVoxData(uvec4 voxData, ivec3 texelCoord){
    imageStore(worldVox,texelCoord,voxData);
}
#endif