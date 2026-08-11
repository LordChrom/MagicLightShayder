#if STAGES == 1
    #define SIZE 2
#elif STAGES == 2
    #define SIZE 4
#elif STAGES == 3
    #define SIZE 8
#elif STAGES == 4
    #define SIZE 16
#endif


const vec2 workGroupsRender = vec2(0.5,0.5);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;


const int ARRAY_SIZE = ((1<<(2*STAGES))-1)/3;
shared uvec4[ARRAY_SIZE] averages;

shared uint anyoneThere;

void main(){
    ivec2 globalPos = ivec2(gl_WorkGroupID.xy*SIZE+gl_LocalInvocationID.xy);
    ivec2 texsize = sourceSize();
    vec2 texcoord = vec2(2*globalPos+1)/(texsize);
    bool stillContributing = texcoord.x<=1 && texcoord.y<=1;

    if(gl_LocalInvocationIndex==0)
        anyoneThere=0;
    barrier();

    atomicOr(anyoneThere,uint(stillContributing));

    uint arrPos = gl_LocalInvocationID.x+(gl_LocalInvocationID.y<<STAGES);
    if(arrPos<ARRAY_SIZE)
        averages[arrPos] = uvec4(0);
    barrier();
    if(anyoneThere==0)
        return;

    uvec4 avg;
    if(stillContributing){
        avg = getValue(texcoord);
        writeValue(globalPos,avg);
    }

    uint contributorMask = ~(gl_LocalInvocationID.x|gl_LocalInvocationID.y);
    uint baseIndex = 0;

    for(int stage=0;stage<STAGES;stage++){
        uint bucket;
        if(stillContributing){
            ivec2 contributePos = ivec2(gl_LocalInvocationID.xy>>(stage+1));
            uint stageShift = STAGES-stage-1;
            bucket = baseIndex + contributePos.x + (contributePos.y<<stageShift);
            baseIndex+=1<<(stageShift+stageShift);

            stillContributing = bool(contributorMask&(1u<<stage));
            combine(averages[bucket].x,avg.x);
            combine(averages[bucket].y,avg.y);
            combine(averages[bucket].z,avg.z);
            combine(averages[bucket].w,avg.w);
        }
        barrier();
        if(stillContributing){
            avg=averages[bucket];
            correction(avg);
            int mipBase = texsize.x-(texsize.x>>(stage+1));
            writeValue(ivec2(mipBase,0)+(globalPos>>(stage+1)),avg);
        }
    }
}