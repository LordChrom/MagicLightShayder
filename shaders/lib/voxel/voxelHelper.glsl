#include "/lib/settings.glsl"



#ifdef SAMPLES_LIGHT_FACE
uniform usampler3D lightVoxSampler;
#endif

#ifdef WRITES_LIGHT_FACE
layout (rgba32ui) uniform writeonly restrict uimage3D lightVox;
#endif


#ifdef SAMPLES_VOX
uniform usampler3D worldVoxSampler;
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
    vec3 lightTravel;//the displacement from the light source voxel center to the sample's voxel center
    float occlusionHitDistance;
    uint type;
    uint flags; //7 free, 1 for whether the light just had translucency applied
};


const float lightTravelScaleInv = 16.0; //most voxels per block representable for lightTravel
const float lightTravelScale = 1.0/lightTravelScaleInv;

const lightVoxData noLight = {vec2(0),bvec4(false),vec3(0),vec3(0),0,0,0};

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
ivec3 axisNumToVec(uint axis){
    mat3 convMat = areaToZoneSpaceMats[axis];
    return ivec3(convMat[0].z,convMat[1].z,convMat[2].z);
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

//TODO include area num
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

//input is is absolute world space, output is world space distance from center of voxel
vec3 subVoxelOffset(vec3 pos, float scale){
    return (fract(pos/scale)-0.5)*scale;
}



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
    ret.occlusionMap = bvec4(packedData.w&0x8000u,packedData.w&0x4000u,packedData.w&0x2000u,packedData.w&0x1000u);
    ret.type = (packedData.w>>8)&0xfu;
    ret.flags = packedData.w&0xffu;
    return ret;
}

uvec4 packLightData(lightVoxData data){
    uvec4 ret;
    uvec4 intTravel = ivec4(round(vec4(data.lightTravel,data.occlusionHitDistance)*lightTravelScaleInv));
    uint intOcclMap =
        (int(data.occlusionMap.x)<<15)|
        (int(data.occlusionMap.y)<<14)|
        (int(data.occlusionMap.z)<<13)|
        (int(data.occlusionMap.w)<<12);

    ret.x = (intTravel.x<<16) | (intTravel.y&0xffffu);
    ret.y = (intTravel.w<<16) | (intTravel.z&0xffffu);
    ret.z = packUnorm4x8(vec4(data.color,0));
    ret.w = (packUnorm4x8(vec4(0,0,data.occlusionRay))&0xffff0000u) | (intOcclMap&0xf000u) | ((data.type&0xfu)<<8) | data.flags&0xffu;
    return ret;
}

uvec4 unpackBytes(uint packedData){
    return uvec4(packedData>>24,packedData>>16,packedData>>8,packedData)&0xffu;
}

uint packBytes(uvec4 data){
    return ((data.x<<24)|(data.y<<16))|((data.z<<8)|(data.w));
}


bvec4 and(bvec4 a, bvec4 b){return bvec4(a.x&&b.x,a.y&&b.y,a.z&&b.z,a.w&&b.w);}
bvec4 or(bvec4 a, bvec4 b){return bvec4(a.x||b.x,a.y||b.y,a.z||b.z,a.w||b.w);}
bvec4 not(bvec4 a){return bvec4(!a.x,!a.y,!a.z,!a.w);}
vec4 ternary(bvec4 conditions,vec4 ifTrue, vec4 ifFalse){
    return vec4(conditions.x?ifTrue.x:ifFalse.x, conditions.y?ifTrue.y:ifFalse.y, conditions.z?ifTrue.z:ifFalse.z, conditions.w?ifTrue.w:ifFalse.w);
}
bool any(bvec4 a){return (a.x||a.y)||(a.z||a.w);}


bool isLit(vec2 slope, vec2 ray, bvec4 map){
    ivec2 pos = ivec2(int(slope.x>ray.x),int(slope.y>ray.y));
    return map[3-pos.x-(pos.y<<1)];
}

bool isLit(vec3 position, lightVoxData light){
    return isLit(abs(position.xy/position.z),light.occlusionRay,light.occlusionMap);
}

#ifdef PENUMBRAS_ENABLED
float penumbralLightTest(vec3 position, lightVoxData light){
    vec2 slope = abs(position.xy/position.z);
    vec2 ray = light.occlusionRay;
    bvec4 map = light.occlusionMap;
    float widthInv = position.z/(PENUMBRA_WIDTH*(position.z-light.occlusionHitDistance));

    vec2 m = clamp((slope-ray)*widthInv,-0.5,0.5);
    vec4 mix = max(vec2(0.5+m.x,0.5-m.x),0).xyxy * max(vec2(0.5+m.y,0.5-m.y),0).xxyy;
    float totalLevel = (int(map.x)*mix.x+int(map.y)*mix.y+int(map.z)*mix.z+int(map.w)*mix.w);
    return totalLevel;
}
#endif

//left, top, right, bottom
bvec4 getOcclusionEdges(bvec4 occlusionMap){
    return not(or(occlusionMap.zxyw,occlusionMap.xywz));
}

//outer x,y, inner xy
bool canIlluminateInBounds(vec4 edges, vec2 ray, bvec4 occlusionMap){
    return any(and(occlusionMap,
        and(
            bvec2(ray.x<edges.x,ray.x>edges.z).xyxy,
            bvec2(ray.y<edges.y,ray.y>edges.w).xxyy
        )
    ));
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
    return texelFetch(worldVoxSampler,texelCoord,0);
}
#endif

#ifdef WRITES_VOX
void setVoxData(uvec4 voxData, ivec3 texelCoord){
    imageStore(worldVox,texelCoord,voxData);
}
#endif