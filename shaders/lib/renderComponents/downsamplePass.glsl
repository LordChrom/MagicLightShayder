#if STAGES == 1
    #define SIZE 2
#elif STAGES == 2
    #define SIZE 4
#elif STAGES == 3
    #define SIZE 8
#elif STAGES == 4
    #define SIZE 16
#endif


#if INDEX_COUNT==1
    #define sampleType uint
#elif INDEX_COUNT==2
    #define sampleType uvec2
#elif INDEX_COUNT==3
    #define sampleType uvec3
#else
    #define sampleType uvec4
#endif

#ifdef PASS_DISABLED
const vec2 workGroupsRender = vec2(0.0,0.0);
#else
const vec2 workGroupsRender = vec2(0.5,0.5);
#endif
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;


const int ARRAY_SIZE = ((1<<(2*STAGES))-1)/3;
shared sampleType[ARRAY_SIZE] averages;

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
        averages[arrPos] = sampleType(0);
    barrier();
    if(anyoneThere==0)
        return;

    sampleType avg;
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
            #if INDEX_COUNT>1
            for(int i=0;i<INDEX_COUNT;i++)
                combine(averages[bucket][i],avg[i]);
            #else
                combine(averages[bucket],avg);
            #endif
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