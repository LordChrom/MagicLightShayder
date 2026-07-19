#version 430
#include "lib/settings.glsl"

#define SIZE 32
#define MAX_RAD 10
const uint bufferWidth = (SIZE+2*MAX_RAD);
const uint bufferSize = bufferWidth*bufferWidth;


const vec2 workGroupsRender = vec2(1.0,1.0);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;


uniform sampler2D colortex0;
uniform sampler2D colortex12;

layout (r32ui) uniform restrict uimage2D dynamicDofImg;
shared uint[bufferWidth][bufferWidth] thebufferrrr;

uniform float centerDepthSmooth;

ivec2 bufferOffset, globalPos;
uint writeColorI;
uint i;
float radius;


void addColorAtPos(ivec2 pos,uint level){
    pos += bufferOffset;
    atomicAdd(thebufferrrr[pos.x][pos.y],writeColorI);
}

void initBuffer(){
    uint pos = gl_LocalInvocationIndex;
    for(uint pos = gl_LocalInvocationIndex; pos<bufferSize;pos+=SIZE*SIZE){
        ivec2 pos2d = ivec2(pos%bufferWidth,pos/bufferWidth);
        thebufferrrr[pos2d.x][pos2d.y]=0u;
    }
    barrier();
}

void flushBuffer(){
    barrier();
    uint pos = gl_LocalInvocationIndex;
    for(uint pos = gl_LocalInvocationIndex; pos<bufferSize;pos+=SIZE*SIZE){
        ivec2 pos2d = ivec2(pos%bufferWidth,pos/bufferWidth);
        ivec2 writePos = pos2d-bufferOffset;
        writePos.x*=3;

        uint value = thebufferrrr[pos2d.x][pos2d.y];
        thebufferrrr[pos2d.x][pos2d.y]=0u;
        imageAtomicAdd(dynamicDofImg,ivec2(writePos.x+i,writePos.y),value);
    }
    barrier();
}

void doTheBlurForOneColor(){
    int rad = int(clamp(abs(radius),0,MAX_RAD));

    writeColorI/=8*rad;
    for(int i=-rad; i<rad; i++){
        ivec2 radi = ivec2(rad,i);
        ivec2 mradi = ivec2(-rad,i);
        addColorAtPos(globalPos+radi.xy,0);
        addColorAtPos(globalPos+radi.yx,0);
        addColorAtPos(globalPos+mradi.xy,0);
        addColorAtPos(globalPos+mradi.yx,0);
    }


    flushBuffer();
}

void main(){
    initBuffer();

    bufferOffset = -ivec2(gl_WorkGroupID.xy*SIZE)+MAX_RAD;
    globalPos = ivec2(gl_WorkGroupID.xy*SIZE+gl_LocalInvocationID.xy);
    vec3 color = texelFetch(colortex0,globalPos,0).rgb;

    radius=texelFetch(colortex12,globalPos,0).y;
    radius=clamp(abs(radius),1,MAX_RAD);


    for(i=0; i<3; i++){
        writeColorI = uint(color[i]*0x00800000u);
        doTheBlurForOneColor();
    }
}