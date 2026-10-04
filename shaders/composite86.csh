#version 430 compatibility
#include "/lib/settings.glsl"


#define SIZE 32
const vec2 workGroupsRender = vec2(1.0,1.0);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;

layout (rgba8) uniform writeonly restrict image2D colorimg14;


uniform sampler2D colortex0;
uniform sampler2D colortex12;

//yes it matters both that these buffers are separated, and that we're saving the one index of space.
shared int[SIZE][SIZE] thebufferrrR;
shared int[SIZE][SIZE] thebufferrrG;
shared int[SIZE][SIZE] thebufferrrB;

vec3 color;
ivec2 samplePos;
float radius;


void initBuffer(){
    thebufferrrR[gl_LocalInvocationID.x][gl_LocalInvocationID.y]=0;
    thebufferrrG[gl_LocalInvocationID.x][gl_LocalInvocationID.y]=0;
    thebufferrrB[gl_LocalInvocationID.x][gl_LocalInvocationID.y]=0;
}

void flushBuffer(){
    ivec3 value = ivec3(0u);
    for(uint x=0; x<=gl_LocalInvocationID.x;x++){
        value+=ivec3(
            thebufferrrR[x][gl_LocalInvocationID.y],
            thebufferrrG[x][gl_LocalInvocationID.y],
            thebufferrrB[x][gl_LocalInvocationID.y]
        );
    }
    imageStore(colorimg14,ivec2(gl_WorkGroupID.xy*gl_WorkGroupSize.xy+gl_LocalInvocationID.xy),vec4(value,0)/DOF_STORAGE_SCALE);
}

void drawLine(int y, int x1, int x2, ivec3 writeColor){
    if(x1>x2)
        return;
    x2++;
    if(y<0 || y>=SIZE)
        return;
    if(x2<0 || x1>=SIZE)
        return;
    x1=max(x1,0);
    atomicAdd(thebufferrrR[x1][y],writeColor.x);
    atomicAdd(thebufferrrG[x1][y],writeColor.y);
    atomicAdd(thebufferrrB[x1][y],writeColor.z);

    if(x2>=SIZE)
        return;
    atomicAdd(thebufferrrR[x2][y],-writeColor.x);
    atomicAdd(thebufferrrG[x2][y],-writeColor.y);
    atomicAdd(thebufferrrB[x2][y],-writeColor.z);
}

//void writeSinglePixel(int x,int y){
//}

void doBlurCircle(){}

void doBlurOctagon(){}

void doBlurSquare(){
    int rad = clamp(int(radius+0.5),1,DOF_RADIUS);

    int x1 = samplePos.x-rad;
    int x2 = samplePos.x+rad;

    ivec3 writeColor=ivec3(round(color*DOF_STORAGE_SCALE/(4.0*radius*radius)));
    ivec3 leftoverColor = ivec3(color*DOF_STORAGE_SCALE*(1-(vec3(1 /(4.0*radius*radius))*(2*rad-1)*(2*rad-1)))/(8*rad));
    #ifdef DOF_TEST_PATTERN
    writeColor*=rad*rad;
    leftoverColor*=rad*rad;
    #endif
    drawLine(samplePos.y+rad,x1,x2,leftoverColor);
    drawLine(samplePos.y-rad,x1,x2,leftoverColor);

    rad--;
//    x1++;
//    x2--;
    for(int y = samplePos.y-rad;y<=samplePos.y+rad;y++){
        drawLine(y,x1,x2,leftoverColor);
        drawLine(y,x1+1,x2-1,writeColor-leftoverColor);
    }
}

void main(){
    initBuffer();
    barrier();

    ivec2 scanAreaStart = max(ivec2(-DOF_RADIUS),-ivec2(gl_WorkGroupID.xy*SIZE));
    ivec2 scanAreaEndExclusive = min(ivec2(SIZE+DOF_RADIUS),textureSize(colortex0,0)-ivec2(gl_WorkGroupID.xy*SIZE));
    int wrap = scanAreaEndExclusive.y-scanAreaStart.y;
    int id = wrap*(scanAreaEndExclusive.x-scanAreaStart.x)-int(gl_LocalInvocationIndex);

    for(;id>=0;id-=SIZE*SIZE){
        samplePos = ivec2(id/wrap, id%wrap)+scanAreaStart;

        radius=texelFetch(colortex12,samplePos + ivec2(gl_WorkGroupID.xy*SIZE),0).y;

        int rad = clamp(int(radius+0.5),0,DOF_RADIUS);
        if (samplePos.x+rad<0 || samplePos.y+rad<0 || samplePos.x-rad>=SIZE || samplePos.y-rad>=SIZE)
            continue;


        color = texelFetch(colortex0,samplePos + ivec2(gl_WorkGroupID.xy*SIZE),0).rgb;

        if(radius<=0.5){
            drawLine(samplePos.y,samplePos.x,samplePos.x,ivec3(color*DOF_STORAGE_SCALE));
            continue;
        }

        radius = clamp(radius,0.5,DOF_RADIUS-0.5);

        #if DOF_SHAPE == 1
        doBlurCircle();
        #elif DOF_SHAPE == 2
        doBlurOctagon();
        #else
        doBlurSquare();
        #endif
    }

    barrier();
    flushBuffer();
}