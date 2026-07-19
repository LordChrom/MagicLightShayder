#version 430
#include "lib/settings.glsl"

#define SIZE 32
#define MAX_RAD 10
#define MAX_LEVEL 4

const uint bufferWidth = (SIZE+2*MAX_RAD);

const int[] scaleOffsets = {0,0,26,40,48};
const int[] bufferBorder = {10,5,3,2,1};

const vec2 workGroupsRender = vec2(1.0,1.0);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;


uniform sampler2D colortex0;
uniform sampler2D colortex12;

layout (r32ui) uniform restrict uimage2D dynamicDofImg;
shared uint[bufferWidth+(bufferWidth>>1)+1][bufferWidth] thebufferrrr;

uniform float centerDepthSmooth;

uint writeColorI;
uint pageOffset;
float radius;


void addColorAtPos(ivec2 pos,uint level){
    pos += bufferBorder[level];
    if(level!=0){
        pos.x+=int(bufferWidth);
        pos.y+=scaleOffsets[level];
    }
    atomicAdd(thebufferrrr[pos.x][pos.y],writeColorI);
}

void initBuffer(){
    const uint fullBufferSize = bufferWidth*(bufferWidth+(bufferWidth>>1)+1);

    for(uint pos = gl_LocalInvocationIndex; pos<fullBufferSize;pos+=SIZE*SIZE){
        ivec2 pos2d = ivec2(pos/bufferWidth,pos%bufferWidth);
        thebufferrrr[pos2d.x][pos2d.y]=0u;
    }
}

void flushBuffer(){
    const uint mainBufferSize = bufferWidth*bufferWidth;

    uint pos = gl_LocalInvocationIndex;
    for(uint pos = gl_LocalInvocationIndex; pos<mainBufferSize;pos+=SIZE*SIZE){
        ivec2 pos2d = ivec2(pos%bufferWidth,pos/bufferWidth);

        uint value = thebufferrrr[pos2d.x][pos2d.y];
//        value=0;
        ivec2 levelPosBase = pos2d-bufferBorder[0];
        for(int level=1; level<=MAX_LEVEL;level++){
            ivec2 levelPos = levelPosBase>>level;
            levelPos += bufferBorder[level];
            levelPos.x+=int(bufferWidth);
            levelPos.y+=scaleOffsets[level];
            value+=thebufferrrr[levelPos.x][levelPos.y];
        }

        imageAtomicAdd(dynamicDofImg,ivec2(pos2d.x+pageOffset,pos2d.y)-MAX_RAD+ivec2(gl_WorkGroupID.xy*SIZE),value);
    }
}

int quantizedCircleArea(int rad){
//    return int(floor(PI*rad*rad));
    int radSquared = rad*rad;
    int ret = 0;
    for(int y=-rad; y<=rad; y++){
        ret+= (int(sqrt(radSquared-y*y))<<1)+1;
    }
    return ret;
}

//the Expensive ones are just for reference
void doBlurSquareExpensive(){
    int rad = int(radius);

    writeColorI=int(writeColorI/((rad+1)*(rad+1)));
    for(int x=-rad; x<=rad; x++){
        for (int y=-rad; y<=rad; y++){
            addColorAtPos(ivec2(x+gl_LocalInvocationID.x, y+gl_LocalInvocationID.y), 0);
        }
    }
}

void doBlurCircleExpensive(){
    int rad = int(ceil(radius));
    int radSquared = rad*rad;
    writeColorI/=quantizedCircleArea(rad);

    for(int y=-rad; y<=rad; y++){
        int xRange = int(sqrt(radSquared-y*y));
        for (int x=-xRange; x<=xRange; x++){
            addColorAtPos(ivec2(x+gl_LocalInvocationID.x, y+gl_LocalInvocationID.y), 0);
        }
    }
}

void doBlurSquare(){
    int rad = int(radius);

    writeColorI=int(writeColorI/(4*radius*radius));
    for(int level = 0; level <= MAX_LEVEL; level++){
        int tmpRad = rad>>level;
        ivec2 basePos = ivec2(gl_LocalInvocationID.xy)>>level;
        for (int i=-tmpRad; i<tmpRad; i++){
            ivec2 radi = ivec2(tmpRad, i);
            ivec2 mradi = ivec2(-tmpRad, i);
            addColorAtPos(basePos+radi.xy, level);
            addColorAtPos(basePos+radi.yx, level);
            addColorAtPos(basePos+mradi.xy, level);
            addColorAtPos(basePos+mradi.yx, level);
        }
    }
}

void doBlurCircle(){
    //veeeeery rough approximation, but i do still kinda like the pixely look
    int rad = int(radius);
    writeColorI=int(writeColorI/(radius*radius*PI));

    for(int level = 0; level <= MAX_LEVEL; level++){
        int tmpRad = rad>>level;
        ivec2 basePos = ivec2(gl_LocalInvocationID.xy)>>level;
        const float pi2 = PI*2;
        int diameter = int(round(tmpRad*pi2));
        for (int i=0; i<diameter;i++){
            float angle = i*pi2/diameter;
            ivec2 offset = ivec2(round(tmpRad*vec2(cos(angle),sin(angle))));
            addColorAtPos(basePos+offset, level);
        }
    }
}

void doTheBlurForOneColor(){
    doBlurCircleExpensive();
}

void main(){
    ivec2 globalPos = ivec2(gl_WorkGroupID.xy*SIZE+gl_LocalInvocationID.xy);

    vec3 color = texelFetch(colortex0,globalPos,0).rgb;
    radius=texelFetch(colortex12,globalPos,0).y;
    uint pageSize = textureSize(colortex0,0).x;


    for(int i=0; i<3; i++){
        initBuffer();
        barrier();

        pageOffset = i*pageSize;
        writeColorI = uint(color[i]*0x00800000u);

        doTheBlurForOneColor();
        barrier();
        flushBuffer();

        if(i<2)
            barrier();
    }
}