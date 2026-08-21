#include "/lib/settings.glsl"

#ifdef OBSTRUCTION_MAPPING
#define SAMPLES_OBSTRUCTION
#endif

#define SAMPLES_FLOOD
#define WRITES_FLOOD
#define SAMPLES_VOX
#include "/lib/voxel/voxelHelper.glsl"


const ivec3 workGroups = ivec3(1,FLOODFILL_SIZE,FLOODFILL_SIZE);
layout (local_size_x = FLOODFILL_SIZE, local_size_y = 1, local_size_z = 1) in;

const float oneLightLevel = 1.0/15.0;
const float oneStep = 1.0/255.0;

ivec3 floodShift;
ivec3 localPos;
vec4 lightOutput;
uint currentBlock;

#ifdef MC_SHAPED_LIGHT_FALLOFF
vec4 decayBlocklight(vec4 source){
    float intensity = (source.r+source.g+source.b)/3.0;
    source.rgb/=intensity;
    intensity=max(0,intensity-oneLightLevel);
    source.rgb*=intensity;
    return source;
}
#else
vec4 decayBlocklight(vec4 source){
    return source*0.8;
}
#endif

void considerSample(ivec3 offset){
    ivec3 samplePos = localPos+offset;
    if(samplePos.x<0 || samplePos.y<0 || samplePos.z<0
    ||samplePos.x>=FLOODFILL_SIZE || samplePos.z>=FLOODFILL_SIZE)
        return;
    if( samplePos.y>=FLOODFILL_SIZE)
        lightOutput.a=1;
    samplePos=modFloodfillSize(samplePos);
    vec4 sampleLight = getFloodData(samplePos, floodShift);
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
    localPos = ivec3(gl_LocalInvocationID.x,gl_WorkGroupID.yz);
    lightOutput=vec4(0);
    floodShift=getFloodShift();


    //TODO make unit scale voxelization a real thing
    #if (FLOODFILL_SIZE>AREA_SIZE)
    ivec3 areaPos;
    ivec3 areaShift;
    uint areaMemOffset;
    for(uint cascade = 0; cascade<NUM_CASCADES;cascade++){
        int scale=int(getScale(cascade));
        if(scale<1)
            continue;
        areaShift = getAreaShift(scale);
        areaPos = ((localPos-(FLOODFILL_SIZE>>1)+(floodShift&(scale-1)))/scale)+(AREA_SIZE>>1);
        int minCoord = min(min(areaPos.x,areaPos.y),areaPos.z);
        int maxCoord = max(max(areaPos.x,areaPos.y),areaPos.z);
        areaMemOffset = areaOffset(cascade);
        if((minCoord>=0) && (maxCoord<AREA_SIZE))
            break;
    }
    #else
        #define areaPos localPos
        #define areaShift floodShift
        #define areaMemOffset 0
    #endif


    currentBlock = getVoxData(areaPos, areaShift, areaMemOffset);
    #ifdef OBSTRUCTION_MAPPING
    uint obstruction = getObstructionData(areaPos, areaShift, areaMemOffset);
    #endif


    if(!bool(currentBlock&WORLDVOX_OPAQUE))
    {
        for(uint i=0;i<6;i++){
            uint axis = i>>1;
            ivec3 offset = ivec3(axis==0,axis==1,axis==2)*(bool(i&1u)?1:-1);

            #ifdef OBSTRUCTION_MAPPING
            if(!bool(obstruction&(1u<<i)))
            #endif
                considerSample(offset);
        }
        lightOutput= decayBlocklight(lightOutput);
    }

    vec3 blockColor = worldVoxColor(currentBlock);
    if (bool(currentBlock&(0xfu<<WORLDVOX_TYPE_SHIFT))){
        lightOutput.rgb=max(lightOutput.rgb,blockColor);
    }else if(bool(currentBlock&WORLDVOX_TRANSLUCENT)){
        lightOutput.rgb*=normalize(blockColor);
    }

    setFloodData(lightOutput, localPos, floodShift);
}

