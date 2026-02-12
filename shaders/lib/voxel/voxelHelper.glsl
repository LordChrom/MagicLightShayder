#define SECTION_WIDTH 16
#define SECTION_DEPTH 16
#define UPDATE_STRIDE 2

#define SLOPE_BITS 7

#define PACKED_POS_MASK 0x00ffffffu


struct lightVoxData{
    uvec3 recolor;
    uint emissive;
    uvec4 slopes;
    vec3 worldPos;
};

const float packedPosScale = 256.0;
const float packedPosScaleInv = 1.0/packedPosScale;

const uint slopeOffset = 1<<(SLOPE_BITS-1);
const uint slopeMask = (1<<SLOPE_BITS)-1;
const float slopeScale = 60.0;

const uint slopeMin = slopeOffset-int(slopeScale);
const uint slopeMax = slopeOffset+int(slopeScale);

const float invSlopeScale = 1.0/slopeScale;
const uvec4 fullLightSpread = uvec2(slopeMax,slopeMin).xyxy;



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

ivec3 axisNumToA(uint axis){
    return axisNumToVec((axis+2)%6u);
}


ivec3 axisNumToB(uint axis){
    return axisNumToVec((axis+4)%6u);
}

ivec3 worldPosToSection(vec3 pos, float scale){
    return ivec3(round(pos+scale));
}


ivec3 worldPosToSection(vec3 pos){
    float scale = 0.5;
    return worldPosToSection(pos,0.5);
}

vec3 sectionPosToWorld(ivec3 pos, float scale){
    return vec3(pos)-scale;
}


vec3 sectionPosToWorld(ivec3 pos){
    float scale = 0.5;
    return sectionPosToWorld(pos,0.5);
}

//uppper A, lower A, upper B, lower B
uvec4 unpackSlopes(uint packed){
    return uvec4(
        slopeMask&(packed>>(4+3*SLOPE_BITS)),
        slopeMask&(packed>>(4+2*SLOPE_BITS)),
        slopeMask&(packed>>(4+1*SLOPE_BITS)),
        slopeMask&(packed>>(4+0*SLOPE_BITS))
    );
}

uint packSlopes(uvec4 slopes){
     return
     ((slopeMask&slopes.x)<<(4+3*SLOPE_BITS))|
     ((slopeMask&slopes.y)<<(4+2*SLOPE_BITS))|
     ((slopeMask&slopes.z)<<(4+1*SLOPE_BITS))|
     ((slopeMask&slopes.w)<<(4+0*SLOPE_BITS));
}

lightVoxData unpackLightData(uvec4 packed){
    lightVoxData ret;
    vec3 worldPos = ((ivec3(packed.xyz&PACKED_POS_MASK)<<8)>>8)*packedPosScaleInv;

    ret.worldPos=worldPos;
    ret.recolor=packed.xyz>>24;
    ret.slopes=unpackSlopes(packed.w);
    ret.emissive=packed.w&0xfu;
    return ret;
}

uvec4 packLightData(lightVoxData data){
    uvec4 ret;
    ret.xyz=(uvec3(data.worldPos*packedPosScale)&PACKED_POS_MASK)+(data.recolor<<24)*0;
    ret.w=packSlopes(data.slopes)+data.emissive;
    return ret;
}



uvec4 combineSlopeBounds(uvec4 boundsA, uvec4 boundsB){
    return uvec4(min(boundsA.xz,boundsB.xz),max(boundsA.yw,boundsB.yw)).xzyw;
}

uvec2 convertSlopesFtoU(vec2 slopesF, float depth){
    return clamp(ivec2(slopeMin),ivec2(trunc(slopesF*(slopeScale/depth)))+slopeOffset,ivec2(slopeMax));
}

uvec4 convertSlopesFtoU(vec4 slopesF, float depth){
    return clamp(ivec4(slopeMin),ivec4(trunc(slopesF*(slopeScale/depth)))+slopeOffset,ivec4(slopeMax));
}

uvec2 convertSlopesFtoU(vec2 slopesF){
    return clamp(ivec2(slopeMin),ivec2(trunc(slopesF*slopeScale))+slopeOffset,ivec2(slopeMax));
}

////worldOffset MUST be in ABP
bool isAdjustedPointInSlopes(vec3 offset, uvec4 slopes){
    uvec2 intSlopes = convertSlopesFtoU(offset.xy,offset.z);
    return (slopes.y<intSlopes.x)&&(intSlopes.x<slopes.x)&&(slopes.w<intSlopes.y)&&(intSlopes.y<slopes.z);
}


//float distFromSource(vec3 sourcePos, vec3 )