#include "/lib/settings.glsl"

#ifdef OBSTRUCTION_MAPPING
#define SAMPLES_OBSTRUCTION
#endif

#define SAMPLES_FLOOD
#define WRITES_FLOOD
#define SAMPLES_VOX
#include "/lib/voxel/voxelHelper.glsl"


const ivec3 workGroups = ivec3(1,AREA_SIZE,AREA_SIZE);
layout (local_size_x = AREA_SIZE, local_size_y = 1, local_size_z = 1) in;

const float oneLightLevel = 1.0/15.0;
const float oneStep = 1.0/255.0;

ivec3 areaShift;
ivec3 areaPos;
vec4 lightOutput;
uint currentBlock;
const uint areaMemOffset = 0;

vec4 decayBlocklight(vec4 source){
    float intensity = (source.r+source.g+source.b)/3.0;
    source.rgb/=intensity;
    intensity=max(0,intensity-oneLightLevel);
    source.rgb*=intensity;
    return source;
}

void considerSample(ivec3 offset){
    ivec3 sampleAreaPos = areaPos+offset;
    if(sampleAreaPos.x<0 || sampleAreaPos.y<0 || sampleAreaPos.z<0
    ||sampleAreaPos.x>=AREA_SIZE || sampleAreaPos.z>=AREA_SIZE)
        return;
    if( sampleAreaPos.y>=AREA_SIZE)
        lightOutput.a=1;
    sampleAreaPos=modAreaSize(sampleAreaPos);
    vec4 sampleLight = getFloodData(sampleAreaPos, areaShift, areaMemOffset);
    sampleLight=decayBlocklight(sampleLight);
    if(offset.y==1){
        if(currentBlock!=0)
            lightOutput.a-=oneLightLevel;
    }else{
        sampleLight.a-=oneLightLevel;
    }

    sampleLight.a=max(0,sampleLight.a);

    lightOutput=max(lightOutput,sampleLight);
}

void main(){
    areaPos = ivec3(gl_LocalInvocationID.x,gl_WorkGroupID.yz);
    lightOutput=vec4(0);
    areaShift=getAreaShift(1.0);

    currentBlock = getVoxData(areaPos, areaShift, areaMemOffset);
    #ifdef OBSTRUCTION_MAPPING
    uint obstruction = getObstructionData(areaPos, areaShift, areaMemOffset);

//    if(!bool(currentBlock&WORLDVOX_SHAPED_BLOCKAGE))
//        obstruction=bool(currentBlock&WORLDVOX_OPAQUE)?0x3fu:0u;
    #endif


//    if(!bool(currentBlock&WORLDVOX_OPAQUE))
    {
        for(uint i=0;i<6;i++){
            uint axis = i>>1;
            ivec3 offset = ivec3(axis==0,axis==1,axis==2)*(bool(i&1u)?1:-1);

            #ifdef OBSTRUCTION_MAPPING
            if(!bool(obstruction&(1u<<i)))
            #endif
                considerSample(offset);
        }
    }

    vec3 blockColor = worldVoxColor(currentBlock);
    if (bool(currentBlock&(0xfu<<WORLDVOX_TYPE_SHIFT))){
        lightOutput.rgb=max(lightOutput.rgb,blockColor);
    }else if(bool(currentBlock&WORLDVOX_TRANSLUCENT)){
        lightOutput.rgb*=normalize(blockColor);
    }

    setFloodData(lightOutput, areaPos, areaShift, areaMemOffset);
}

