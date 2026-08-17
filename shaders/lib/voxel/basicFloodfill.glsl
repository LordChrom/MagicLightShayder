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

void considerSample(int x, int y, int z){
    ivec3 sampleAreaPos = areaPos+ivec3(x,y,z);
    if(sampleAreaPos.x<0 || sampleAreaPos.y<0 || sampleAreaPos.z<0
    ||sampleAreaPos.x>=AREA_SIZE || sampleAreaPos.z>=AREA_SIZE)
        return;
    if( sampleAreaPos.y>=AREA_SIZE)
        lightOutput.a=1;
    sampleAreaPos=modAreaSize(sampleAreaPos);
    vec4 sampleLight = getFloodData(sampleAreaPos, areaShift, areaMemOffset);
    sampleLight=decayBlocklight(sampleLight);
    if(y==1){
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

    if(!bool(currentBlock&WORLDVOX_OPAQUE)){
        considerSample(1, 0, 0);
        considerSample(-1, 0, 0);
        considerSample(0, 1, 0);
        considerSample(0, -1, 0);
        considerSample(0, 0, 1);
        considerSample(0, 0, -1);
    }

    vec3 blockColor = worldVoxColor(currentBlock);
    if (bool(currentBlock&(0xfu<<VOXEL_TYPE_SHIFT))){
        lightOutput.rgb=max(lightOutput.rgb,blockColor);
    }else if(bool(currentBlock&WORLDVOX_TRANSLUCENT)){
        lightOutput.rgb*=normalize(blockColor);
    }

    setFloodData(lightOutput, areaPos, areaShift, areaMemOffset);
}

