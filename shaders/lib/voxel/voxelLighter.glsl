
// rgb is the worldPos of the light source's center
//a encodes partial occlusion, as 4 bits empty, 4x 6 bit slope cutoffs, 4 bits strength.
//each angular cutoff is an inverse slope indicating angle off occlusion from light source, mapping linearly from [0,50] to [-1,1]
layout (rgba32f) uniform coherent restrict image3D lightVox;


layout (rgba8ui) uniform readonly restrict uimage3D worldVox;
#include "/lib/voxel/voxelHelper.glsl"




#define FULL_SPREAD ( (50<<22) + (50<<16) )
#define NO_LIGHT 0

uniform int frameCounter;
int frameOffset = frameCounter%UPDATE_STRIDE;

const ivec3 workGroups = ivec3(1,1,1);
layout (local_size_x = SECTION_WIDTH, local_size_y = SECTION_WIDTH, local_size_z = 1) in;

void lightVoxel(ivec3 sectionPos, uint section,ivec3 progress,uint axisNum){
    vec3 mainWorldPos = sectionPosToWorld(sectionPos);
    float scale = 0.5;

    vec3 bestSource = vec3(0);
    uint bestSpread = NO_LIGHT;
    float bestStrength = -10000000;
    int bestAxis = -2;

    //potential contributions from all nearby neighbors
    for (int i=-1;i<4;i++){
        int axisDir = int(((axisNum|1u)+1+i)%6);
        ivec3 offset = axisNumToVec(axisDir);

        if(i<0) offset=ivec3(0);

        ivec3 voxPos = sectionPos+offset-progress;
        vec3 worldPos = sectionPosToWorld(voxPos);

        uvec4 voxel = imageLoad(worldVox, voxPos);
        vec4 source = imageLoad(lightVox, voxPos);

        uint emissive = voxel.a>>4;

        if((voxel.a&1u)==1u && emissive==0) //voxel occludes, and doesnt transmit or emit, light passing into it cannot pass out
            continue;

        uint spread = floatBitsToUint(source.a);


        if(emissive>0){
            source.xyz = worldPos;
            spread = FULL_SPREAD+emissive;
        }

        vec3 disp = mainWorldPos-source.xyz;
        float lenSquared = max(0.5,disp.x*disp.x + disp.y*disp.y + disp.z*disp.z);
        float strength = float(spread&0xfu)/lenSquared;

        if(i>=0){
            uint slopeLower = int(0x3fu&(spread>>(4+6*(i&1))));
            uint slopeUpper = int(0x3fu&(spread>>(16+6*(i&1))));

            slopeLower=0;
            slopeUpper=40;

            float rise = dot(disp,abs(offset));
            float run = dot(disp,progress);

            float slopeF = rise/run;
            uint slopeI = uint(clamp(0,(slopeF+1)*50,50));
            if(!(slopeLower <= slopeI && slopeI <= slopeUpper))
                continue;
        }

        if(strength>bestStrength){
            bestSource=source.xyz;
            bestStrength=strength;
            bestAxis = axisDir;
            bestSpread = spread;
        }

    }


    imageStore(lightVox,sectionPos,vec4(bestSource,uintBitsToFloat(bestSpread)));
}

void lightVoxels(uvec3 groupId, uvec3 localId){
    uint section = 0;
    ivec3 sectionPos = ivec3(localId)+ivec3(1);

    ivec3 progress = axisNumToVec(debugAxisNum);

    for(int i = frameOffset;i<SECTION_DEPTH;i+=UPDATE_STRIDE){
        lightVoxel(sectionPos+progress*i,section,progress,debugAxisNum);
        groupMemoryBarrier();
    }
}

