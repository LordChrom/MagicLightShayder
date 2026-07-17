#if STAGES == 1
    #define SIZE 2
#elif STAGES == 2
    #define SIZE 4
#elif STAGES == 3
    #define SIZE 8
#elif STAGES == 4
    #define SIZE 16
#endif

const vec2 workGroupsRender = vec2(LIGHTING_RENDERSCALE,LIGHTING_RENDERSCALE);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;

uniform sampler2D source;

const int ARRAY_SIZE = ((1<<(2*STAGES))-1)/3;
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

    uint contributorMask = ~(gl_LocalInvocationID.x|gl_LocalInvocationID.y);
    uint baseIndex = 0;
    for(int stage=0;stage<STAGES;stage++){
        ivec2 contributePos = ivec2(gl_LocalInvocationID.xy>>(stage+1));
        uint stageShift = STAGES-stage-1;
        uint bucket = baseIndex + contributePos.x + (contributePos.y<<stageShift);
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
            ivec2 texsize = textureSize(source,0);
            ivec2 mipBase = texsize-(texsize>>stage);
            imageStore(dest,mipBase+(globalPos>>(stage+1)),uvec4(avg*1024/1e6));
        }
    }
}