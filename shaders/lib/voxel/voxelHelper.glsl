#define SECTION_WIDTH 16
#define SECTION_DEPTH 16
#define UPDATE_STRIDE 2

#define SLOPE_BITS 7

#define PACKED_POS_MASK 0x00ffffff


//axes for voxel faces are represented as a,b,d, with d being the direction light travels in, a being the axis after it, and b being the one after that
//all examples are xyz,yx-z, zxy,zx-y,yzx,yz-x
struct lightVoxData{
//illumination and occlusion both represent, of a rectangular pyramid from the source, the slope to the corner which
//shares an a,b quarant with the sample. A position is lit if it's inside illumination and outside occlusion
    vec2 illumination;
    vec2 occlusion;
    vec3 color;
    uint emission; //blocklight strength. Potentially redundant w/ color.
    vec3 lightTravel; //the displacement from the light source voxel center to the sample's voxel center
};


//const float packedPosScale = 256.0;
//const float packedPosScaleInv = 1.0/packedPosScale;

const float lightTravelScaleInv = 16.0; //most voxels per block representable for lightTravel
const float lightTravelScale = 1.0/lightTravelScaleInv;

const lightVoxData noLight = {vec2(0),vec2(0),vec3(0),0,vec3(0)};

const int debugAxisNum = 5;

bool isVoxelInBounds(vec3 worldPos){
    return worldPos.x>=0 && worldPos.y>=0 && worldPos.z>=0 && worldPos.x<16 && worldPos.y<16 && worldPos.z<16;
}


//in order from 0 to 5, -x,+x,-y,+y,-z,+z
//lsb is 0=neg,1=pos
//returns 0,0,0 when axis out of range
ivec3 axisNumToVec(uint axis){
    uint upper = axis>>1u;
    return ivec3(upper==0,upper==1,upper==2)*(((int(axis)&1)<<1)-1);
}



ivec3 worldPosToSection(vec3 pos, float scale){
    return ivec3(round(pos/scale+0.5)*scale);
}

vec3 subVoxelOffset(vec3 pos, float scale){
    return (fract(pos/scale)-0.5)*scale;
}



//bit layout of the packing
//first uint is 2x16 a,b of travel
//second is 1x16 free, 1x16 z of travel
//third is 3x8 color, 1x4 unused, 1x4 emissive strength,
//4th is 2x8 illumination, 2x8 occlusion,
lightVoxData unpackLightData(uvec4 packedData){
    lightVoxData ret;
    ret.lightTravel = vec3(ivec3(packedData.x,packedData.x<<16,packedData.y<<16)>>16)*lightTravelScale;
    ret.emission = packedData.z&0xfu;
    ret.color=unpackUnorm4x8(packedData.z).yzw;
    return ret;
}

uvec4 packLightData(lightVoxData data){
    uvec4 ret;
    uvec3 intTravel = ivec3(round(data.lightTravel*lightTravelScaleInv));
    ret.x = (intTravel.x<<16) | (0xffffu&intTravel.y);
    ret.y = intTravel.z;
    ret.z = (data.emission&0xfu) | (0xffffff00u&packUnorm4x8(vec4(0,data.color)));
    ret.w = packUnorm4x8(vec4(data.illumination,data.occlusion));
    return ret;
}