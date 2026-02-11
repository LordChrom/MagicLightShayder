
//+z in lightVox space is always the direction along which light propogates
//rgb are offset to light source
//a encodes partial occlusion
layout (rgba16f) uniform coherent restrict image3D lightVox;
layout (rgba8ui) uniform readonly restrict uimage3D worldVox;


#define SECTION_WIDTH 16
#define SECTION_DEPTH 16
#define UPDATE_INTERVAL 2

uniform int frameCounter;
int frameOffset = frameCounter%UPDATE_INTERVAL;

const int stepCount = SECTION_DEPTH/UPDATE_INTERVAL;
//const ivec3 progressDir = ivec3(0,0,1);
//const ivec3 progress = progressDir*UPDATE_INTERVAL;

const ivec3 workGroups = ivec3(1,1,1);
layout (local_size_x = SECTION_WIDTH, local_size_y = SECTION_WIDTH, local_size_z = 1) in;


//shared vec3[16][16] lightRelative;
//shared vec3[16][16] lightRange;

void lightVoxel(ivec3 sectionPos, uint section,ivec3 progress){
    vec4 voxOutput = vec4(0);
//    vec4 thisVox = imageLoad(lightVox,sectionPos);
    uvec4 thisBlock = imageLoad(worldVox,sectionPos);
    uint transmissive = (thisBlock.a&1u)^1u;
    uint emissive = thisBlock.a>>4;

    vec3 incomingLight;
    float cutoff;
    if(emissive>0){
        incomingLight = vec3(0);
        cutoff=emissive/16;
        cutoff=1;
    }else{
        vec4 tmp = imageLoad(lightVox,sectionPos+ivec3(1)-progress);
        incomingLight = vec3(tmp.xyz);
        cutoff = tmp.a*0.8*transmissive;
    }

    vec3 outgoingLight = incomingLight-progress;
    if(cutoff==0)
        outgoingLight=vec3(0);
    imageStore(lightVox,sectionPos+ivec3(1),vec4(outgoingLight,cutoff));

}

void lightVoxels(uvec3 groupId, uvec3 localId){
    uint section = 0;
    ivec3 sectionPos = ivec3(localId);

    ivec3 progress = ivec3(0,0,1);

    for(int i = frameOffset;i<SECTION_DEPTH;i+=UPDATE_INTERVAL){
        lightVoxel(sectionPos+progress*i,section,progress);
        groupMemoryBarrier();
    }
}

