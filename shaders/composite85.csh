#version 430
#extension GL_KHR_shader_subgroup_vote : enable
#include "lib/settings.glsl"


#define SIZE 16
#define MAX_RAD 10
#define MAX_LEVEL 4


const vec2 workGroupsRender = vec2(1.0,1.0);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;


const uint bufferWidth = (SIZE+2*MAX_RAD);
const ivec2 actualBufferSize = ivec2(bufferWidth+(bufferWidth>>1)+1,bufferWidth);

layout (r32ui) uniform restrict uimage2D dynamicDofImg;
shared uint[actualBufferSize.x][actualBufferSize.y] thebufferrrr;


uniform sampler2D colortex0;
uniform sampler2D colortex12;


uint writeColorI;
uint pageOffset;
uint pageSize;
float radius;

#ifdef DOF2_TEST_PATTERN
int debugNum;
#endif


int bufferBorder(uint level){
    return int((MAX_RAD+((1<<level)-1))>>level);
}

int scaleOffset(uint level){
    if(level==0) return 0;
    level--;
    return int(
        bufferWidth-(bufferWidth>>level)+level//bitCount(bufferWidth<<(32-level))
    );
}

void initBuffer(){
    const uint fullBufferSize = actualBufferSize.x*actualBufferSize.y;

    for(uint pos = gl_LocalInvocationIndex; pos<fullBufferSize;pos+=SIZE*SIZE){
        ivec2 pos2d = ivec2(pos/actualBufferSize.y,pos%actualBufferSize.y);
        thebufferrrr[pos2d.x][pos2d.y]=0u;
    }
}

void addColorAtPos(ivec2 pos,uint level, uint data){
    #ifdef DOF2_TEST_PATTERN
    if(bool(level&(1u<<debugNum)))
    return;
    #endif

    pos += bufferBorder(level);
    if(bool(level)){
        pos.x+=int(bufferWidth);
        pos.y+=scaleOffset(level);
    }
    atomicAdd(thebufferrrr[pos.x][pos.y],data);
}

void drawLine(ivec2 pos, ivec2 step, int steps, uint level, uint data){
    #define DRAW_SHORTCUT
    #ifdef DRAW_SHORTCUT
        #ifdef DOF2_TEST_PATTERN
        if(bool(level&(1u<<debugNum)))
        return;
        #endif

    pos += bufferBorder(level);
    if(level!=0){
        pos.x+=int(bufferWidth);
        pos.y+=scaleOffset(level);
    }
    for(int i=0; i<steps; i++){
        atomicAdd(thebufferrrr[pos.x][pos.y],data);
        pos+=step;
    }

    #else

    for(int i=0; i<steps; i++){
        addColorAtPos(pos,level,data);
        pos+=step;
    }

    #endif
}

void flushBuffer(){
    const uint mainBufferSize = bufferWidth*bufferWidth;

    for(uint pos = gl_LocalInvocationIndex; pos<mainBufferSize;pos+=SIZE*SIZE){
        ivec2 pos2d = ivec2(pos%bufferWidth,pos/bufferWidth);

        uint value = thebufferrrr[pos2d.x][pos2d.y];

        ivec2 levelPosBase = pos2d-bufferBorder(0);
        for(int level=1; level<=MAX_LEVEL;level++){
            ivec2 levelPos = levelPosBase>>level;
            levelPos += bufferBorder(level);
            levelPos.x+=int(bufferWidth);
            levelPos.y+=scaleOffset(level);
            value+=thebufferrrr[levelPos.x][levelPos.y];
        }

        pos2d+=ivec2(gl_WorkGroupID.xy*SIZE)-MAX_RAD;
        if(pos2d.x>=0 && pos2d.x<pageSize && value!=0)
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

    int actualArea = (rad+rad+1);
    actualArea*=actualArea;
    float desiredArea = 4.0*radius*radius;
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
    int actualArea = (rad+rad+1);
    actualArea*=actualArea;

    float desiredArea = 4.0*radius*radius;
    uint fullWeightColor = int(writeColorI/desiredArea);
    #ifdef DOF2_TEST_PATTERN
    if(fullWeightColor>0) fullWeightColor=0x00400000;
    #endif
    if(fullWeightColor<0x10)fullWeightColor=0;


    ivec4 miniBounds = ivec4(gl_LocalInvocationID.xyxy);
    miniBounds.xy-=rad;
    miniBounds.zw+=rad;

    int effort = 3; //1 to rad*2
    effort=min(effort,rad+rad);

    int edgePixels = rad<<3;
    float edgeWeight=1-(actualArea-desiredArea)/edgePixels;
    uint edgeWeightedColor = uint(fullWeightColor*edgeWeight*edgePixels/(4*effort));

    for (int i=0; i<effort; i++){
        int offset = (rad*i<<1)/effort;
        addColorAtPos(miniBounds.xy+ivec2(0, offset), 0, edgeWeightedColor);
        addColorAtPos(miniBounds.xw+ivec2(offset, 0), 0, edgeWeightedColor);
        addColorAtPos(miniBounds.zy-ivec2(offset, 0), 0, edgeWeightedColor);
        addColorAtPos(miniBounds.zw-ivec2(0, offset), 0, edgeWeightedColor);
    }
    rad--;

    if(fullWeightColor==0)return;


    //min xy, max xy
    ivec4 bounds = ivec4(gl_LocalInvocationID.xyxy);
    bounds.xy-=rad;
    bounds.zw+=rad;


    ivec2 edgeXY = ivec2(bool(bounds.x&1)?bounds.x:bounds.z,bool(bounds.y&1)?bounds.y:bounds.w);
    ivec2 marchOrigin = bounds.xy+(bounds.xy&1)-1;
    addColorAtPos(ivec2(edgeXY), 0,fullWeightColor);
    for (int i=1; i<rad*2+1; i++){
        addColorAtPos(ivec2(marchOrigin.x+i,edgeXY.y), 0,fullWeightColor);
        addColorAtPos(ivec2(edgeXY.x,marchOrigin.y+i), 0,fullWeightColor);
    }


    int level;
    for(level = 1; level <= MAX_LEVEL; level++){
        bounds = (bounds+ivec4(1,1,-1,-1))>>1;
        if(bounds.z<bounds.x || bounds.w<bounds.y)return;
        if(((bounds.z-bounds.x<=1) && (bounds.w-bounds.y<=1)) || level==MAX_LEVEL){
            break;
        }

        int xsteps = 1+bounds.z-bounds.x;
        //TODO could probably be made to iterate less times by having the edges all be in the same loop
        if(bool( bounds.y  &1)){
            drawLine(bounds.xy,ivec2(1,0),xsteps,level,fullWeightColor);
        }

        if(bool((~bounds.w)&1)){
            drawLine(bounds.xw,ivec2(1,0),xsteps,level,fullWeightColor);
        }

        int yIterStart = bounds.y+(bounds.y&1);
        int ysteps = (bounds.w+((bounds.w)&1)) - yIterStart;

        if(bool( bounds.x  &1)){
            drawLine(ivec2(bounds.x,yIterStart),ivec2(0,1),ysteps,level,fullWeightColor);
        }

        if(bool((~bounds.z)&1)){
            drawLine(ivec2(bounds.z,yIterStart),ivec2(0,1),ysteps,level,fullWeightColor);
        }
    }

//    bounds = (bounds+ivec4(1,1,-1,-1))>>1;
    if(bounds.z<bounds.x || bounds.w<bounds.y)return;
    for(int x=bounds.x;x<=bounds.z;x++){
        for(int y=bounds.y;y<=bounds.w;y++){
            addColorAtPos(ivec2(x,y), level, fullWeightColor);
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
    float ogRadius = radius=texelFetch(colortex12,globalPos,0).y;
    pageSize = textureSize(colortex0,0).x;


    for(int i=0; i<3; i++){
        #ifdef DOF2_TEST_PATTERN
        debugNum = i;
        #endif
        #ifdef DOF_ABBERATION
        radius = min(ogRadius,MAX_RAD-0.5);
        radius = max(0.5,radius-2*i);
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