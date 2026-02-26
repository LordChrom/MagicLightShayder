#include "/lib/settings.glsl"



#ifdef SAMPLES_LIGHT_FACE
uniform usampler3D lightVoxSampler;
#endif

//layout (rgba32ui) uniform restrict uimage3D lightVox;

#ifdef WRITES_LIGHT_FACE
layout (rgba32ui) uniform writeonly restrict uimage3D lightVox;
#endif


#endif

#ifdef SAMPLES_VOX
uniform usampler3D worldVoxSampler;
//layout (rgba8ui) uniform precise readonly restrict uimage3D worldVox;
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
    float columnation;
};


const float lightTravelScaleInv = 16.0; //most voxels per block representable for lightTravel
const float lightTravelScale = 1.0/lightTravelScaleInv;

const lightVoxData noLight = {vec2(0),bvec4(false),vec3(0),0,vec3(0),0};

bool isVoxelInBounds(vec3 worldPos){
    worldPos-=voxOriginOffset;
    return worldPos.x>=0 && worldPos.y>=0 && worldPos.z>=0 && worldPos.x<voxWorldSize.x && worldPos.y<voxWorldSize.y && worldPos.z<voxWorldSize.z;
}


const mat3[] areaToZoneSpaceMats = {
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
    return ivec3(areaToZoneSpaceMats[axis]*vec3(0,0,1));
}



//output.xyz is area xyz
//output.w is area number
ivec4 worldPosToArea(vec3 pos, float scale){
    pos-=voxOriginOffset;
    ivec3 sectionID = ivec3(floor(pos/AREA_SIZE));
    pos-=AREA_SIZE*sectionID;
    int areaNum = (sectionID.x<<(AREA_SHIFT+AREA_SHIFT)) + (sectionID.y<<AREA_SHIFT) + sectionID.z;

    return ivec4(ivec3(round(pos/scale+0.5)*scale),areaNum);
}

uint zoneOffset(uint axis, uint layer){
    return int((ZONE_OFFSET)*(VOX_LAYERS*axis+layer));
}

ivec3 areaToZoneSpace(ivec4 areaPos, uint axis, uint layer){
    uint upper = axis>>1u;
    ivec3 ret = areaPos.xyz;
    switch(upper){
        case 0u:
            ret=areaPos.yzx;
            break;
        case 1u:
            ret=areaPos.zxy;
            break;
        case 2u:
            ret=areaPos.xyz;
            break;
        default:
            ret=ivec3(0);
            break;
    }

    if((axis&1u)==0u){
        ret.z=(AREA_SIZE-1)-ret.z;
    }

    ret.z+=int(zoneOffset(axis,layer)); //TODO fix overlap better

    return ret;
}

vec3 subVoxelOffset(vec3 pos, float scale){
    return (fract(pos/scale)-0.5)*scale;
}



//to consider: frexp and idexp

//bit layout of the packing
//x is 2x16 a,b of travel
//y is 2x8 occlusion (b then a), 1x16 z of travel
//z is 3x8 color, 1x8 columnation
//w is 24 free, 1x4 occlusion map, 1x4 emissive strength,
lightVoxData unpackLightData(uvec4 packedData){
    lightVoxData ret;
    ret.lightTravel = vec3(ivec3(packedData.x,packedData.x<<16,packedData.y<<16)>>16)*lightTravelScale;
    vec4 colorAndColumnation = unpackUnorm4x8(packedData.z);
    ret.color=colorAndColumnation.xyz;
    ret.columnation=colorAndColumnation.w;
    ret.emission = packedData.w&0xfu;
    ret.occlusionMap = bvec4(packedData.w&0x80u,packedData.w&0x40u,packedData.w&0x20u,packedData.w&0x10u);
    ret.occlusionRay=unpackUnorm4x8(packedData.y).zw; //higher bits are later vec elements
    return ret;
}

uvec4 packLightData(lightVoxData data){
    uvec4 ret;
    uvec3 intTravel = ivec3(round(data.lightTravel*lightTravelScaleInv));
    uvec4 intOcclMap = uvec4(data.occlusionMap)<<uvec4(7,6,5,4);

    ret.x = (intTravel.x<<16) | (0xffffu&intTravel.y);
    ret.y = intTravel.z | (packUnorm4x8(vec4(0,0,data.occlusionRay))&0xffff0000u);
    ret.z = packUnorm4x8(vec4(data.color,data.columnation));
    ret.w = (data.emission&0xfu) | (0xf0u&((intOcclMap.x|intOcclMap.y)|(intOcclMap.z|intOcclMap.w)));
    return ret;
}



bvec4 and(bvec4 a, bvec4 b){return bvec4(a.x&&b.x,a.y&&b.y,a.z&&b.z,a.w&&b.w);}
bvec4 or(bvec4 a, bvec4 b){return bvec4(a.x||b.x,a.y||b.y,a.z||b.z,a.w||b.w);}
bvec4 not(bvec4 a){return bvec4(!a.x,!a.y,!a.z,!a.w);}

bool isLit(vec2 slope, vec2 ray, bvec4 map){
    ivec2 pos = ivec2(int(slope.x>ray.x),int(slope.y>ray.y));
    return map[3-pos.x-(pos.y<<1)] && (slope.x<=1) && (slope.y<=1);
}

bool isLit(vec3 position, vec2 ray, bvec4 map){
    vec2 slope = abs(position.xy/position.z);
//    ivec2 pos = ivec2(int(slope.x>ray.x),int(slope.y>ray.y));
//    return map[3-pos.x-(pos.y<<1)] && (slope.x<=1) && (slope.y<=1);
    return isLit(slope,ray,map);
}

bool isLit(vec3 position, lightVoxData light){
    return isLit(position,light.occlusionRay,light.occlusionMap);
}

//left, top, right, bottom
bvec4 getOcclusionEdges(bvec4 occlusionMap){
    return not(or(occlusionMap.zxyw,occlusionMap.xywz));
}

bool canIlluminateInBounds(vec4 edges, vec2 ray, bvec4 occlusionMap){
    //TODO this can clearly be done better but it's late rn
    return
    isLit(edges.xy,ray,occlusionMap) ||
    isLit(edges.xw,ray,occlusionMap) ||
    isLit(edges.zy,ray,occlusionMap) ||
    isLit(edges.zw,ray,occlusionMap);
}

vec4 ternary(bvec4 conditions,vec4 ifTrue, vec4 ifFalse){
    ivec4 tmp = ivec4(conditions);
    return ifTrue*tmp+(1-tmp)*ifFalse;
}



#ifdef SAMPLES_LIGHT_FACE
uvec4 getRawLightData(ivec3 texelCoord){
    return texelFetch(lightVoxSampler, texelCoord,0);
}

lightVoxData getLightData(ivec3 texelCoord){
    uvec4 packedData = texelFetch(lightVoxSampler, texelCoord,0);
    return unpackLightData(packedData);
}

lightVoxData getLightData(ivec4 sectionPos, uint axis, uint layer){
    ivec3 texelCoord = areaToZoneSpace(sectionPos,axis,layer);
    return getLightData(texelCoord);
}
#endif

#ifdef WRITES_LIGHT_FACE
void setLightData(lightVoxData light, ivec3 texelCoord){
    uvec4 packedData = packLightData(light);
    imageStore(lightVox,texelCoord, packedData);
}
void setLightData(lightVoxData light, ivec4 sectionPos, uint axis,uint layer){
    ivec3 texelCoord = areaToZoneSpace(sectionPos,axis,layer);
    setLightData(light,texelCoord);
}
#endif

#ifdef SAMPLES_VOX
uvec4 getVoxData(ivec3 texelCoord){
//    return imageLoad(worldVox,texelCoord);
    return texelFetch(worldVoxSampler,texelCoord,0);
}
#endif

#ifdef WRITES_VOX
void setVoxData(uvec4 voxData, ivec3 texelCoord){
    imageStore(worldVox,texelCoord,voxData);
}
#endif