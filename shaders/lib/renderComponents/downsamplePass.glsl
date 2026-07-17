#if STAGES == 1
    #define SIZE 2
#elif STAGES == 2
    #define SIZE 4
#elif STAGES == 3
    #define SIZE 8
#elif STAGES == 4
    #define SIZE 16
#endif

#ifdef USE_DEPTH_A
    uniform sampler2D depthtex1;
    #include "/lib/util/conversions.glsl"
#endif

//TODO figure out how to multiply by PASS_SCALE, since the workGroupsRender thing is super annoying with floats
const vec2 workGroupsRender = vec2(0.5,0.5);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;

uniform sampler2D source;

const float scale = 1048576;
const int ARRAY_SIZE = ((1<<(2*STAGES))-1)/3;
shared uvec4[ARRAY_SIZE] averages;

shared uint anyoneThere = 0;

void main(){
    ivec2 globalPos = ivec2(gl_WorkGroupID.xy*SIZE+gl_LocalInvocationID.xy);
    ivec2 texsize = textureSize(source,0);
    vec2 texcoord = vec2(2*globalPos+1)/(texsize);
    bool stillContributing = texcoord.x<=1 && texcoord.y<=1;

    atomicOr(anyoneThere,uint(stillContributing));
    barrier();
    if(anyoneThere==0)
        return;

    uint arrPos = gl_LocalInvocationID.x+(gl_LocalInvocationID.y<<STAGES);
    if(arrPos<ARRAY_SIZE)
        averages[arrPos] = uvec4(0);
    barrier();

    uvec4 avg;
    if(stillContributing){
        vec4 self = texture(colortex7, texcoord);
        imageStore(dest, globalPos, self);
        #ifdef USE_DEPTH_A
            self.a=depthToLinear(texture(depthtex1 ,vec2(globalPos)/texsize).x);
        #endif
        avg = uvec4(self*scale);
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
            atomicAdd(averages[bucket].x,avg.x);
            atomicAdd(averages[bucket].y,avg.y);
            atomicAdd(averages[bucket].z,avg.z);
            atomicAdd(averages[bucket].w,avg.w);
        }
        barrier();
        if(stillContributing){
            avg=averages[bucket]>>2u;
            int mipBase = texsize.x-(texsize.x>>(stage+1));
            imageStore(dest,ivec2(mipBase,0)+(globalPos>>(stage+1)),avg/scale);
        }
    }
}