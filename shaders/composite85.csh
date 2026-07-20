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



void initBuffer(){
    const uint fullBufferSize = bufferWidth*(bufferWidth+(bufferWidth>>1)+1);

    for(uint pos = gl_LocalInvocationIndex; pos<fullBufferSize;pos+=SIZE*SIZE){
        ivec2 pos2d = ivec2(pos/bufferWidth,pos%bufferWidth);
        thebufferrrr[pos2d.x][pos2d.y]=0u;
    }
}

void addColorAtPos(ivec2 pos,uint level, uint data){
    #ifdef DOF2_TEST_PATTERN
    if(bool(level&(1u<<debugNum)))
    return;
    #endif

    pos += bufferBorder[level];
    if(level!=0){
        pos.x+=int(bufferWidth);
        pos.y+=scaleOffsets[level];
    }
    atomicAdd(thebufferrrr[pos.x][pos.y],data);
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
    int radSquared = rad*rad;
    int ret = rad;
    for(int y=1; y<=rad; y++){
        ret+= int(sqrt(radSquared-y*y));
    }
    return (ret<<2)+1;
}

//reference implementation
void doBlurSquareExpensive(){
    int rad = clamp(int(radius+0.5),0,MAX_RAD);

    float desiredArea = 4.0*radius*radius;
    int actualArea = (rad+rad+1);
    actualArea*=actualArea;
    int edgePixels = rad<<3;

    float edgeWeight=1-(actualArea-desiredArea)/edgePixels;

    uint fullWeightColor = int(writeColorI/desiredArea);
    #ifdef DOF2_TEST_PATTERN
    if(fullWeightColor>0) fullWeightColor=0x00800000;
    #endif
    uint edgeWeightedColor = uint(fullWeightColor*edgeWeight);

    for(int x=-rad; x<=rad; x++){
        for (int y=-rad; y<=rad; y++){
            addColorAtPos(ivec2(x+gl_LocalInvocationID.x, y+gl_LocalInvocationID.y), 0,
                ((max(abs(x),abs(y))==rad))?edgeWeightedColor:fullWeightColor
            );
        }
    }
}

void doBlurSquare(){

    int rad = clamp(int(radius+0.5),0,MAX_RAD);

    float desiredArea = 4.0*radius*radius;
    int actualArea = (rad+rad+1);
    actualArea*=actualArea;
    int edgePixels = rad<<3;

    float edgeWeight=1-(actualArea-desiredArea)/edgePixels;

    uint fullWeightColor = int(writeColorI/desiredArea);
    #ifdef DOF2_TEST_PATTERN
    if(fullWeightColor>0) fullWeightColor=0x00800000;
    #endif
    uint edgeWeightedColor = uint(fullWeightColor*edgeWeight);
    uint cornerWeightedColor = edgeWeightedColor;

    //min xy, max xy
    ivec4 bounds = ivec4(gl_LocalInvocationID.xyxy);
    bounds.xy-=rad;
    bounds.zw+=rad;


    ivec2 edgeXY = ivec2(bool(bounds.x&1)?bounds.x:bounds.z,bool(bounds.y&1)?bounds.y:bounds.w);
    ivec2 marchOrigin = bounds.xy+(bounds.xy&1)-1;
    addColorAtPos(ivec2(edgeXY), 0,cornerWeightedColor);
    for (int i=1; i<rad*2+1; i++){
        addColorAtPos(ivec2(marchOrigin.x+i,edgeXY.y), 0,edgeWeightedColor);
        addColorAtPos(ivec2(edgeXY.x,marchOrigin.y+i), 0,edgeWeightedColor);
    }

    bvec4 edgeExposed = bvec4(
        bounds.x!=edgeXY.x,
        bounds.y!=edgeXY.y,
        bounds.z!=edgeXY.x,
        bounds.w!=edgeXY.y
    );




    for(int level = 1; level <= MAX_LEVEL; level++){
        bounds = (bounds+ivec4(1,1,-1,-1))>>1;
        if(bounds.z<bounds.x || bounds.w<bounds.y)break;

        if(bounds.xy==bounds.zw){
//            addColorAtPos(bounds.xy,level,fullWeightColor);
//            break;
        }

        bvec4 allowableEdges = bvec4(
            (bounds.x&1),
            (bounds.y&1),
            ((~bounds.z)&1),
            ((~bounds.w)&1)
        );

        cornerWeightedColor = (edgeWeightedColor>>1)+(cornerWeightedColor>>2)+(fullWeightColor>>2);
        edgeWeightedColor=(edgeWeightedColor>>1)+(fullWeightColor>>1);


        bvec4 cornersVisible= bvec4(
            allowableEdges.x||allowableEdges.y,
            allowableEdges.x||allowableEdges.w,
            allowableEdges.z||allowableEdges.y,
            allowableEdges.z||allowableEdges.w
        );

        bvec4 cornersExposed = bvec4( //BL TL BR TR
            edgeExposed.x&&edgeExposed.y,
            edgeExposed.x&&edgeExposed.w,
            edgeExposed.z&&edgeExposed.y,
            edgeExposed.z&&edgeExposed.w
        );

        if(bounds.x==bounds.z){
            cornersVisible=bvec4(
                cornersVisible.x||cornersVisible.z,
                cornersVisible.y||cornersVisible.w,
                false,
                false
            );

            cornersExposed=bvec4(
                cornersExposed.x||cornersExposed.z,
                cornersExposed.y||cornersExposed.w,
                false,
                false
            );
        }

        if(bounds.y==bounds.w){
            cornersVisible=bvec4(
                cornersVisible.x||cornersVisible.y,
                false,
                cornersVisible.z||cornersVisible.w,
                false
            );

            cornersExposed=bvec4(
                cornersExposed.x||cornersExposed.y,
                false,
                cornersExposed.z||cornersExposed.w,
                false
            );
        }

//        if()
        if(cornersVisible.x)
            addColorAtPos(bounds.xy,level,cornersExposed.x?cornerWeightedColor:((edgeExposed.x||edgeExposed.y)?edgeWeightedColor:fullWeightColor));
        if(cornersVisible.y)
            addColorAtPos(bounds.xw,level,cornersExposed.y?cornerWeightedColor:((edgeExposed.x||edgeExposed.w)?edgeWeightedColor:fullWeightColor));
        if(cornersVisible.z)
            addColorAtPos(bounds.zy,level,cornersExposed.z?cornerWeightedColor:((edgeExposed.z||edgeExposed.y)?edgeWeightedColor:fullWeightColor));
        if(cornersVisible.w)
            addColorAtPos(bounds.zw,level,cornersExposed.w?cornerWeightedColor:((edgeExposed.z||edgeExposed.w)?edgeWeightedColor:fullWeightColor));

        ivec2 iterBounds = bounds.xz;
        iterBounds.x+=1;//int(allowableEdges.y);
        iterBounds.y-=1;//int(allowableEdges.w);

        //TODO could probably be made to iterate less times by having the edges all be in the same loop
        if(allowableEdges.y){
            writeColorI = edgeExposed.y?edgeWeightedColor:fullWeightColor;
            edgeExposed.y=false;
            for (int x=iterBounds.x;x<=iterBounds.y;x++){
                addColorAtPos(ivec2(x, bounds.y), level, writeColorI);
            }
        }

        if(allowableEdges.w){
            writeColorI = edgeExposed.w?edgeWeightedColor:fullWeightColor;
            edgeExposed.w=false;
            for (int x=iterBounds.x;x<=iterBounds.y;x++){
                addColorAtPos(ivec2(x, bounds.w), level, writeColorI);
            }
        }

        iterBounds = bounds.yw;
        iterBounds.x+=1;//int(allowableEdges.y);
        iterBounds.y-=1;//int(allowableEdges.w);


        if(allowableEdges.x){
            writeColorI = edgeExposed.x?edgeWeightedColor:fullWeightColor;
            edgeExposed.x=false;
            for (int y=iterBounds.x;y<=iterBounds.y;y++){
                addColorAtPos(ivec2(bounds.x, y), level, writeColorI);
            }
        }

        if(allowableEdges.z){
            writeColorI = edgeExposed.z?edgeWeightedColor:fullWeightColor;
            edgeExposed.z=false;
            for (int y=iterBounds.x;y<=iterBounds.y;y++){
                addColorAtPos(ivec2(bounds.z, y), level, writeColorI);
            }
        }

    }
}

//reference implementation
void doBlurCircleExpensive(){
    int rad = clamp(int(radius),0,MAX_RAD);
    int radSquared = rad*rad;
    writeColorI/=quantizedCircleArea(rad);

    for(int y=-rad; y<=rad; y++){
        int xRange = int(sqrt(radSquared-y*y));
        for (int x=-xRange; x<=xRange; x++){
            addColorAtPos(ivec2(x+gl_LocalInvocationID.x, y+gl_LocalInvocationID.y), 0,writeColorI);
        }
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
            addColorAtPos(basePos+offset, level,writeColorI);
        }
    }
}

//uniform float frameTimeCounter;

void doTheBlurForOneColor(){
    if(radius<=0.501){
        addColorAtPos(ivec2(gl_LocalInvocationID.xy), 0,writeColorI);
        return;
    }

    radius = clamp(radius,0.5,MAX_RAD-0.5);

//    if(fract(frameTimeCounter*0.5)>0.5)
//        doBlurSquareExpensive();
//    else
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