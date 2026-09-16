#include "/lib/settings.glsl"

#define SAMPLES_FLOOD
#define WRITES_FLOOD
#define SAMPLES_VOX
#include "/lib/voxelStorage/blockPacking.glsl"
#include "/lib/lighting/floodShadows/voxelHelper.glsl"
#include "/lib/util/dither.glsl"


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

const ivec3 workGroups = ivec3(WORK_SIZE,WORK_SIZE,WORK_SIZE);
layout (local_size_x = 16, local_size_y = 1, local_size_z = 16) in;

const float oneLightLevel = 1.0/15.0;
const float oneStep = 1.0/255.0;

ivec3 floodShift;
ivec3 localPos;
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

uint getBlock(ivec3 blockPos){
//    ivec3 areaPos;
//    ivec3 areaShift;
//    uint areaMemOffset;
//    #if (FLOODFILL_SIZE!=AREA_SIZE)
//    for(uint cascade = 0; cascade<NUM_CASCADES;cascade++){
//        int scale=int(getScale(cascade));
//        if(scale<1)
//            continue;
//        areaShift = getAreaShift(scale);
//        areaPos = ((blockPos-(FLOODFILL_SIZE>>1)+(floodShift&(scale-1)))/scale)+(AREA_SIZE>>1);
//        int minCoord = min(min(areaPos.x,areaPos.y),areaPos.z);
//        int maxCoord = max(max(areaPos.x,areaPos.y),areaPos.z);
//        areaMemOffset = areaOffset(cascade);
//        if((minCoord>=0) && (maxCoord<AREA_SIZE))
//            break;
//    }
//    #else
//    areaPos = blockPos;
//    areaShift = floodShift;
//    areaMemOffset = 0;
//    #endif

    return getBaseVoxData(blockPos, getUnitShift());
}

void considerSample(ivec3 samplePos, uint axis){
    if(samplePos.x<0 || samplePos.y<0 || samplePos.z<0
    ||samplePos.x>=FLOODFILL_SIZE || samplePos.z>=FLOODFILL_SIZE)
        return;
    if( samplePos.y>=FLOODFILL_SIZE)
        lightOutput.a=1;
    samplePos=modFloodfillSize(samplePos);
    uint sampleBlock = getBlock(samplePos);
    vec4 sampleLight = getFloodData(samplePos, floodShift);

    bool blockCutOff = (!bool(packUnorm4x8(sampleLight)&1u))
    || (blockBlocksFace(sampleBlock,axis^1u)&&!bool(sampleBlock&(WORLDVOX_TRANSLUCENT|WORLDVOX_EMISSION_MASK)));

    if(blockCutOff)
        return;

    if(axis==3){
        if(centerBlock!=0)
            lightOutput.a-=0.01;
    }else{
        sampleLight.a-=0.01;
    }

    sampleLight.a=max(0,sampleLight.a);

    lightOutput=max(lightOutput,sampleLight);
}

uint bayer2u3d(uvec3 pos){
    return ((pos.x&1u)<<2)+((pos.y&1u)<<1)+(pos.z&1u);
}

uint bayer4u3d(uvec3 pos){
    return (bayer2u3d(pos)<<3)|(bayer2u3d(pos>>1));
}

void main(){
    floodShift=getUnitShift();

    //TODO make this handled by more appropriate work groups
    if(gl_WorkGroupID.y==0){
        ivec3 movement = clamp(floodShift-getPreviousUnitShift(),-FLOODFILL_SIZE,FLOODFILL_SIZE);
        ivec3 movementSigns = sign(movement);
        ivec3 edgeToTrim = abs(movement);

        ivec2 posXY = ivec2(gl_LocalInvocationID.xz)+ivec2(gl_WorkGroupID.xz<<4);
        for(int i=0; i<edgeToTrim.x;i++){
            int x = movementSigns.x>0?(FLOODFILL_SIZE-1)-i:i;
            setFloodData(vec4(0),ivec3(x,posXY.xy),floodShift);
        }
        for(int i=0; i<edgeToTrim.y;i++){
            int y = movementSigns.y>0?(FLOODFILL_SIZE-1)-i:i;
            setFloodData(vec4(0),ivec3(posXY.x,y,posXY.y),floodShift);
        }
        for(int i=0; i<edgeToTrim.z;i++){
            int z = movementSigns.z>0?(FLOODFILL_SIZE-1)-i:i;
            setFloodData(vec4(0),ivec3(posXY.xy,z),floodShift);
        }
    }

    //TODO seam filling, probably shared mem also
    #define DISTANCE_BASED_FLOODFILL_SPEED
    #ifdef DISTANCE_BASED_FLOODFILL_SPEED
    ivec3 centerness = ivec3(gl_WorkGroupID)-(WORK_SIZE>>1)+1;
    centerness=abs(centerness-clamp(centerness,0,1));
    uint distFromCenter = max(max(centerness.x,centerness.y),centerness.z);

    uint updatePeriod = max(distFromCenter*distFromCenter,1);
    bool shouldCompute = (((bayer4u3d(gl_WorkGroupID)+frameCounter)%updatePeriod)==0);
    #ifdef JUMPSTART_LIGHTING
    shouldCompute=shouldCompute||frameCounter<20;
    #endif
    if(!shouldCompute)
        return;
    #endif


    for(int i=0;i<16;i++){
        localPos = ivec3(gl_LocalInvocationID+(gl_WorkGroupID<<4));
        localPos.y+=15-i;
        lightOutput=vec4(0);

        //TODO make unit scale voxelization a real thing

        centerBlock = getBlock(localPos);

        bool lightTotallyBlocked = bool(centerBlock&WORLDVOX_OPAQUE);

        {
            for(uint axis=0;axis<6;axis++){
                uint absAxis = axis>>1;
                ivec3 offset = ivec3(absAxis==0,absAxis==1,absAxis==2)*(bool(axis&1u)?1:-1);

                bool sampleVisible = true;
                if(lightTotallyBlocked){
                    float cameraFacingness = dot(offset,normalize(localPos-(FLOODFILL_SIZE/2)));
                    //TODO fix this nonsense
                    if(cameraFacingness>0)
                        continue;
                    else
                        sampleVisible=true;
                }else{
                    sampleVisible = bool(centerBlock&WORLDVOX_TRANSLUCENT)||!blockBlocksFace(centerBlock,axis);
                }

                ivec3 samplePos = localPos+offset;

                if(sampleVisible)
                    considerSample(samplePos,axis);
            }
            lightOutput= decay(lightOutput);
        }

        vec3 blockColor = worldVoxColor(centerBlock);
        if (bool(centerBlock&(0xfu<<WORLDVOX_TYPE_SHIFT))){
            lightOutput.rgb=max(lightOutput.rgb,blockColor);
            lightTotallyBlocked=false;
        }else if(bool(centerBlock&WORLDVOX_TRANSLUCENT)){
            lightOutput.rgb*=normalize(blockColor);
        }

        uint packedLight = packUnorm4x8(lightOutput);
        packedLight = (packedLight&~1u)|uint(!lightTotallyBlocked);
        lightOutput=unpackUnorm4x8(packedLight);

        setFloodData(lightOutput, localPos, floodShift);
    }
}

