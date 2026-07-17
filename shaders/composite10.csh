#version 430

#define SIZE 8
//1,5,21

//const ivec3 workGroups = ivec3(1,1,1);
const vec2 workGroupsRender = vec2(1,1);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;

layout (rgba16) uniform writeonly restrict image2D colorimg7;
uniform sampler2D colortex7;

#if SIZE==2
    #define ARRAY_SIZE 1
    #define STAGES 1
#elif SIZE==4
    #define ARRAY_SIZE 5
    #define STAGES 2
#elif SIZE==8
    #define ARRAY_SIZE 21
    #define STAGES 3
#elif SIZE==16
    #define ARRAY_SIZE 85
    #define STAGES 4
#endif

shared uvec4[ARRAY_SIZE] averages;

void main(){
    ivec2 globalPos = ivec2(gl_WorkGroupID.xy*SIZE+gl_LocalInvocationID.xy);
    vec4 self = texelFetch(colortex7,globalPos,0);

    uint arrPos = gl_LocalInvocationID.x+(gl_LocalInvocationID.y<<STAGES);
    if(arrPos<ARRAY_SIZE)
        averages[arrPos] = uvec4(0);
    barrier();

    uvec4 selfUvec = uvec4(self*1e6);
    uvec4 avg = selfUvec;

    bool stillContributing = true;

    uint[STAGES] buckets;
    uint contributorMask = ~(gl_LocalInvocationID.x|gl_LocalInvocationID.y);
    uint baseIndex = 0;
    for(int stage=0;stage<STAGES;stage++){
        ivec2 contributePos = ivec2(gl_LocalInvocationID.xy>>(stage+1));
        uint stageShift = STAGES-stage-1;
        uint bucket = baseIndex + contributePos.x + (contributePos.y<<stageShift);
        buckets[stage]=bucket;
        baseIndex+=1<<(stageShift+stageShift);
        if(stillContributing){
            stillContributing = bool(contributorMask&(1u<<stage));
            atomicAdd(averages[bucket].x,avg.x);
            atomicAdd(averages[bucket].y,avg.y);
            atomicAdd(averages[bucket].z,avg.z);
            atomicAdd(averages[bucket].w,avg.w);
        }
        barrier();
        if(stillContributing){
            avg=averages[bucket]>>2u;
        }
    }

    selfUvec=uvec4(0);
    for(int stage=0;stage<STAGES;stage++){
        selfUvec+=averages[buckets[stage]]>>2;
    }

    imageStore(colorimg7,globalPos,selfUvec*(1e-6/(STAGES)));
}