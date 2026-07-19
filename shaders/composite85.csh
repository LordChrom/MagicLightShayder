#version 430
#include "lib/settings.glsl"


#define SIZE 32
#define MAX_RAD 10
#define MAX_LEVEL 4

const uint bufferWidth = (SIZE+2*MAX_RAD);
const int[] bufferBorder = {MAX_RAD,(MAX_RAD+0x1)>>1,(MAX_RAD+0x3)>>2,(MAX_RAD+0x7)>>3,(MAX_RAD+0xf)>>4};
const int[] scaleOffsets = {
    0,0,
    ((SIZE>>1)+2*bufferBorder[1]),
    ((SIZE>>1)+2*bufferBorder[1]) + ((SIZE>>2)+2*bufferBorder[2]),
    ((SIZE>>1)+2*bufferBorder[1]) + ((SIZE>>2)+2*bufferBorder[2]) + ((SIZE>>3)+2*bufferBorder[3]),
};


const vec2 workGroupsRender = vec2(1.0,1.0);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;


layout (r32ui) uniform restrict uimage2D dynamicDofImg;
shared uint[bufferWidth+(bufferWidth>>1)+1][bufferWidth] thebufferrrr;



uniform sampler2D colortex0;
uniform sampler2D colortex12;


uint writeColorI;
uint pageOffset;
uint pageSize;
float radius;

#ifdef DOF2_TEST_PATTERN
int debugNum;
#endif

void addColorAtPos(ivec2 pos,uint level){
    #ifdef DOF2_TEST_PATTERN
    if(bool(level&(1u<<debugNum)))
        return;
    #endif

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

        pos2d+=ivec2(gl_WorkGroupID.xy*SIZE)-MAX_RAD;
        if(pos2d.x>=0 && pos2d.x<pageSize)
            imageAtomicAdd(dynamicDofImg,ivec2(pos2d.x+pageOffset,pos2d.y),value);
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
    int rad = clamp(int(radius),0,MAX_RAD);


    writeColorI=int(writeColorI/((2*rad+1)*(2*rad+1)));
    for(int x=-rad; x<=rad; x++){
        for (int y=-rad; y<=rad; y++){
            addColorAtPos(ivec2(x+gl_LocalInvocationID.x, y+gl_LocalInvocationID.y), 0);
        }
    }
}

void doBlurCircleExpensive(){
    int rad = clamp(int(radius),0,MAX_RAD);
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
    int rad = clamp(int(abs(radius)-0.5),0,MAX_RAD);
    float edgeWeight = fract(abs(radius)-0.5);

    writeColorI=int(writeColorI/((2*rad+1)*(2*rad+1)));

    #ifdef DOF2_TEST_PATTERN
    if(writeColorI>0) writeColorI=0x00800000;
    #endif

    //min xy, max xy
    ivec4 bounds = ivec4(gl_LocalInvocationID.xyxy);
    bounds.xy-=rad;
    bounds.zw+=rad;

    ivec2 edgeXY = ivec2(bool(bounds.x&1)?bounds.x:bounds.z,bool(bounds.y&1)?bounds.y:bounds.w);
    ivec2 marchOrigin = bounds.xy+(bounds.xy&1)-1;
    addColorAtPos(ivec2(edgeXY), 0);
    for (int i=1; i<rad*2+1; i++){
        addColorAtPos(ivec2(marchOrigin.x+i,edgeXY.y), 0);
        addColorAtPos(ivec2(edgeXY.x,marchOrigin.y+i), 0);
    }

    for(int level = 1; level <= MAX_LEVEL; level++){
        bounds = (bounds+ivec4(1,1,-1,-1))>>1;
        if(bounds.z<bounds.x || bounds.w<bounds.y)break;

        if(bounds.xy==bounds.zw){
            addColorAtPos(bounds.xy,level);
            break;
        }

        bvec4 allowableEdges = bvec4(
            (bounds.x&1),
            (bounds.y&1),
            ((~bounds.z)&1),
            ((~bounds.w)&1)
        );

        //TODO could probably be made to iterate less times by having the edges all be in the same loop
        if(allowableEdges.y)
            for(int x=bounds.x;x<=bounds.z;x++)
                addColorAtPos(ivec2(x,bounds.y),level);

        if(allowableEdges.w)
            for(int x=bounds.x;x<=bounds.z;x++)
                addColorAtPos(ivec2(x,bounds.w),level);

        ivec2 iterBoundsY = bounds.yw;
        iterBoundsY.x+=int(allowableEdges.y);
        iterBoundsY.y-=int(allowableEdges.w);


        if(allowableEdges.x)
            for(int y=iterBoundsY.x;y<=iterBoundsY.y;y++)
                addColorAtPos(ivec2(bounds.x,y),level);

        if(allowableEdges.z)
            for(int y=iterBoundsY.x;y<=iterBoundsY.y;y++)
                addColorAtPos(ivec2(bounds.z,y),level);

    }
}

void doBlurCircle(){
    //veeeeery rough approximation, but i do still kinda like the pixely look
    int rad = clamp(int(radius),0,MAX_RAD);
    writeColorI/=quantizedCircleArea(rad);

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
    doBlurSquare();
}

void main(){
    ivec2 globalPos = ivec2(gl_WorkGroupID.xy*SIZE+gl_LocalInvocationID.xy);

    vec3 color = texelFetch(colortex0,globalPos,0).rgb;
    radius=texelFetch(colortex12,globalPos,0).y;
    pageSize = textureSize(colortex0,0).x;


    for(int i=0; i<3; i++){
        #ifdef DOF2_TEST_PATTERN
        debugNum = i;
        #endif

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