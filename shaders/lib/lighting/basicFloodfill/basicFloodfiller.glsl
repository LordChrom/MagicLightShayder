#include "/lib/settings.glsl"

#define SAMPLES_FLOOD
#define WRITES_FLOOD
#define READS_BASE_VOX
#include "/lib/voxelStorage/blockPacking.glsl"
#include "/lib/lighting/floodShadows/voxelHelper.glsl"


#if FLOODFILL_SIZE<=32
    #define WORK_SIZE 2
#elif FLOODFILL_SIZE<=64
    #define WORK_SIZE 4
#elif FLOODFILL_SIZE<=128
    #define WORK_SIZE 8
#elif FLOODFILL_SIZE<=192
    #define WORK_SIZE 12
#elif FLOODFILL_SIZE<=256
    #define WORK_SIZE 16
#else
    #define WORK_SIZE 24
#endif

#define SIZE 16
#include "/lib/util/dither3d.glsl"

const ivec3 workGroups = ivec3(WORK_SIZE,WORK_SIZE,WORK_SIZE);
layout (local_size_x = SIZE, local_size_y = 1, local_size_z = SIZE) in;

const float oneLightLevel = 1.0/15.0;
const float oneStep = 1.0/255.0;

ivec3 unitShift;
vec4 lightOutput;
uint centerBlock;

#ifdef MC_SHAPED_LIGHT_FALLOFF
vec3 decayBlocklight(vec3 source){
    float intensity = (source.r+source.g+source.b)/3.0;
    source/=intensity;
    intensity=max(0,intensity-oneLightLevel);
    source*=intensity;
    return source;
}
float decaySunlight(float sunlight){
    return sunlight==1.0?1.0:(sunlight-oneLightLevel);
}
#else
vec3 decayBlocklight(vec3 source){
    return source.rgb*0.8;
}
float decaySunlight(float sunlight){
    return sunlight==1.0?1.0:sunlight*0.8;
}
#endif

vec4 decay(vec4 source){
    return vec4(decayBlocklight(source.rgb),decaySunlight(source.a));
}

void considerSample(ivec3 samplePos, uint axis){
    if(samplePos.x<0 || samplePos.y<0 || samplePos.z<0
    ||samplePos.x>=FLOODFILL_SIZE || samplePos.z>=FLOODFILL_SIZE)
        return;

    if( samplePos.y>=FLOODFILL_SIZE){
        lightOutput.a=1;
        return;
    }

    samplePos=modFloodfillSize(samplePos);
    uint sampleBlock = getBaseVoxData(samplePos,unitShift);
    vec4 sampleLight = getFloodData(samplePos, unitShift);

    if((!bool(packUnorm4x8(sampleLight)&1u))
        || (worldVoxBlocksFace(sampleBlock,axis^1u)&&!bool(sampleBlock&(WORLDVOX_TRANSLUCENT|WORLDVOX_EMISSION_MASK)))
    ){
        return;
    }

    if(axis==3){
        if(centerBlock!=0)
            lightOutput.a-=0.01;
    }else{
        sampleLight.a-=0.01;
    }

    sampleLight.a=max(0,sampleLight.a);

    lightOutput=max(lightOutput,sampleLight);
}

bool outOfFloodRange(int pos,int margin){
    return pos<max(0,margin) || pos>=(FLOODFILL_SIZE+min(0,margin));
}

void movementTrim(){
    ivec3 movement = clamp(getPreviousUnitShift()-unitShift,-FLOODFILL_SIZE,FLOODFILL_SIZE);

    ivec3 pos;
    pos.xz=ivec2(SIZE*gl_WorkGroupID.xz)+ivec2(gl_LocalInvocationID.xz);
    if(outOfFloodRange(pos.x,movement.x) || outOfFloodRange(pos.z,movement.z)){
        for(uint i=0;i<SIZE;i++){
            pos.y=int(SIZE*gl_WorkGroupID.y+i);
            setFloodData(vec4(0),pos,unitShift);
        }
    }

    int wgYOffset = int(SIZE*gl_WorkGroupID.y);
    ivec2 yRange = movement.y>0?
    ivec2(0,max(0,movement.y)-wgYOffset):
    ivec2((FLOODFILL_SIZE+min(0,movement.y))-wgYOffset,SIZE)
    ;
    yRange.x=max(yRange.x,0);
    yRange.y=min(yRange.y,SIZE);

    for(int i=yRange.x;i<yRange.y;i++){
        pos.y=int(wgYOffset+i);
        setFloodData(vec4(0),pos,unitShift);
    }
}

void main(){
    unitShift=getUnitShift();
    movementTrim();

    //TODO make this handled by more appropriate work groups

    //TODO probably would benefit from shared mem
    #define DISTANCE_BASED_FLOODFILL_SPEED
    #ifdef DISTANCE_BASED_FLOODFILL_SPEED
    bool shouldCompute = shouldCompute(getUpdatePeriod());
    #ifdef JUMPSTART_LIGHTING
    shouldCompute=shouldCompute||frameCounter<20;
    #endif
    if(!shouldCompute)
        return;
    #endif

    ivec3 localPos;
    localPos.xz = ivec2(gl_LocalInvocationID.xz+(gl_WorkGroupID.xz<<4));

    for(int i=0;i<16;i++){
        localPos.y=int(gl_LocalInvocationID.y+(gl_WorkGroupID.y<<4))+15-i;
        lightOutput=vec4(0);

        //TODO make unit scale voxelization a real thing

        centerBlock = getBaseVoxData(localPos,unitShift);

        bool lightTotallyBlocked = bool(centerBlock&WORLDVOX_OPAQUE);


        for(uint axis=0;axis<6;axis++){
            ivec3 offset = ivec3(axis>>1==0,axis>>1==1,axis>>1==2)*(bool(axis&1u)?1:-1);

            if(lightTotallyBlocked){
                float cameraFacingness = dot(offset,normalize(localPos-(FLOODFILL_SIZE/2)));
                //TODO fix this nonsense
                if(cameraFacingness>0)
                    continue;
            }else if(worldVoxBlocksFace(centerBlock,axis)&&!bool(centerBlock&WORLDVOX_TRANSLUCENT)){
                    continue;
            }

            considerSample(localPos+offset,axis);
        }
        lightOutput= decay(lightOutput);


        vec3 blockColor = worldVoxColor(centerBlock);
        if (bool(centerBlock&WORLDVOX_EMISSION_MASK)){
            lightOutput.rgb=max(lightOutput.rgb,blockColor);
            lightTotallyBlocked=false;
        }else if(bool(centerBlock&WORLDVOX_TRANSLUCENT)){
            lightOutput.rgb*=normalize(blockColor);
        }

        uint packedLight = packUnorm4x8(lightOutput);
        packedLight = (packedLight&~1u)|uint(!lightTotallyBlocked);
        lightOutput=unpackUnorm4x8(packedLight);

        setFloodData(lightOutput, localPos, unitShift);
    }
}

