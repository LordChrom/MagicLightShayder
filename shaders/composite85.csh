#version 430
#include "lib/settings.glsl"


#define SIZE 32
#define MAX_RAD 8
#define MAX_LEVEL 4


const vec2 workGroupsRender = vec2(1.0,1.0);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;



layout (r32ui) uniform restrict uimage2D dynamicDofImg;
shared uint[SIZE+SIZE][SIZE+SIZE] thebufferrrr;


uniform sampler2D colortex0;
uniform sampler2D colortex12;

ivec2 samplePos;
uint writeColorI;
int pageOffset;
int pageSize;
float radius;

#ifdef DOF2_TEST_PATTERN
int debugNum;
#endif

void initBuffer(){
    int id = int(gl_LocalInvocationIndex);
    id<<=2;
    ivec2 pos = ivec2(id/(2*SIZE),id%(2*SIZE));
    for(int i=0;i<4;i++){
        thebufferrrr[pos.x][pos.y+i]=0u;
    }
}

void flushBuffer(){
    uint value = 0;

    ivec2 level;
    for(level.x=0; level.x<=MAX_LEVEL;level.x++){
        for(level.y=0; level.y<=MAX_LEVEL;level.y++){
            ivec2 levelPos = ivec2(gl_LocalInvocationID.xy+SIZE)>>level;
            value+=thebufferrrr[levelPos.x][levelPos.y];
        }
    }

    ivec2 pos = ivec2(gl_WorkGroupID.xy*SIZE+gl_LocalInvocationID.xy);
    if(pos.x>=0 && pos.x<pageSize && value!=0)
        imageAtomicAdd(dynamicDofImg,ivec2(pos.x+pageOffset,pos.y),value);
}



void write(ivec2 pos,ivec2 level, uint data){
    if((pos.x>=(SIZE>>level.x))||(pos.y>=(SIZE>>level.y))||(pos.x<0) || (pos.y<0))
        return;
    #ifdef DOF2_TEST_PATTERN
    if(bool(((level.x+level.y)%7)&(1<<debugNum))) return;
    #endif

    pos+=ivec2(SIZE)>>level;
    atomicAdd(thebufferrrr[pos.x][pos.y],data);
}


void drawLine(ivec2 pos, ivec2 step, int steps, int level, uint data){
    for(int i=0; i<steps; i++){
        write(pos,ivec2(level),data);
        pos+=step;
    }
}

void drawLineX(ivec2 pos, int steps, int startingLevel, uint color){
    int level;
    ivec2 bounds = ivec2(pos.x,pos.x+steps-1);

    for(level = startingLevel; level < MAX_LEVEL; level++){
        if(bounds.y<bounds.x)return;
        if(bounds.y-bounds.x<=1){
            break;
        }

        if(bool( bounds.x  &1))
            write(ivec2(bounds.x,pos.y),ivec2(level,startingLevel),color);

        if(bool((~bounds.y)&1))
            write(ivec2(bounds.y,pos.y),ivec2(level,startingLevel),color);

        bounds = (bounds+ivec2(1,-1))>>1;
    }

    if(bounds.y<bounds.x)return;
    for(int x=bounds.x;x<=bounds.y;x++){
        write(ivec2(x,pos.y),ivec2(level,startingLevel),color);
    }
}

void drawLineY(ivec2 pos, int steps, int startingLevel, uint color){
    int level;
    ivec2 bounds = ivec2(pos.y,pos.y+steps-1);

    for(level = startingLevel; level < MAX_LEVEL; level++){
        if(bounds.y<bounds.x)return;
        if(bounds.y-bounds.x<=1){
            break;
        }

        if(bool( bounds.x  &1))
        write(ivec2(pos.x,bounds.x),ivec2(startingLevel,level),color);

        if(bool((~bounds.y)&1))
        write(ivec2(pos.x,bounds.y),ivec2(startingLevel,level),color);

        bounds = (bounds+ivec2(1,-1))>>1;
    }

    if(bounds.y<bounds.x)return;
    for(int y=bounds.x;y<=bounds.y;y++){
        write(ivec2(pos.x,y),ivec2(startingLevel,level),color);
    }
}


void drawRectangle(ivec4 bounds, uint color, int startingLevel){
    int level;

    bounds = clamp(bounds,0,SIZE);

    for(int i=0; i<startingLevel;i++){
        bounds = (bounds+ivec4(1,1,-1,-1))>>1;
    }

    for(level = startingLevel; level < MAX_LEVEL; level++){
        if(bounds.z<bounds.x || bounds.w<bounds.y)return;
        if((bounds.z-bounds.x<=1) && (bounds.w-bounds.y<=1)){
            break;
        }

        int xsteps = 1+bounds.z-bounds.x;
        if(bool( bounds.y  &1))
            drawLineX(bounds.xy,xsteps,level,color);

        if(bool((~bounds.w)&1))
            drawLineX(bounds.xw,xsteps,level,color);

        int yIterStart = bounds.y+(bounds.y&1);
        int ysteps = (bounds.w+((bounds.w)&1)) - yIterStart;

        if(bool( bounds.x  &1))
            drawLineY(ivec2(bounds.x,yIterStart),ysteps,level,color);

        if(bool((~bounds.z)&1))
            drawLineY(ivec2(bounds.z,yIterStart),ysteps,level,color);

        bounds = (bounds+ivec4(1,1,-1,-1))>>1;
    }

    if(bounds.z<bounds.x || bounds.w<bounds.y)return;
    int xSteps = 1+bounds.z-bounds.x;
    for(int y=bounds.y;y<=bounds.w;y++){
        drawLineX(ivec2(bounds.x,y),xSteps,level,color);
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
    uint edgeWeightedColor = uint(fullWeightColor*edgeWeight);

    for(int x=-rad; x<=rad; x++){
        for (int y=-rad; y<=rad; y++){
            write(ivec2(x+samplePos.x, y+samplePos.y), ivec2(0),
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
    if(fullWeightColor<0x10)fullWeightColor=0;


    ivec4 miniBounds = ivec4(samplePos.xyxy);
    miniBounds.xy-=rad;
    miniBounds.zw+=rad;

    int maxEdgeEffort = 3; //1 to rad*2
    maxEdgeEffort=min(maxEdgeEffort,rad+rad);

    int edgePixels = rad<<3;
    float edgeWeight=1-(actualArea-desiredArea)/edgePixels;
    uint edgeWeightedColor = (writeColorI-(fullWeightColor*(2*rad-1)*(2*rad-1)))/(maxEdgeEffort<<2);

    for (int i=0; i<maxEdgeEffort; i++){
        int offset = (rad*i<<1)/maxEdgeEffort;
//        write(miniBounds.xy+ivec2(0, offset), ivec2(0), edgeWeightedColor);
//        write(miniBounds.xw+ivec2(offset, 0), ivec2(0), edgeWeightedColor);
//        write(miniBounds.zy-ivec2(offset, 0), ivec2(0), edgeWeightedColor);
//        write(miniBounds.zw-ivec2(0, offset), ivec2(0), edgeWeightedColor);
    }
    rad--;

    if(fullWeightColor==0)return;

    //min xy, max xy
    ivec4 bounds = ivec4(samplePos.xyxy);
    bounds.xy-=rad;
    bounds.zw+=rad;

    ivec2 edgeXY = ivec2(bool(bounds.x&1)?bounds.x:bounds.z,bool(bounds.y&1)?bounds.y:bounds.w);
    write(ivec2(edgeXY), ivec2(0),fullWeightColor);
    drawLineX(ivec2(bounds.x+(bounds.x&1),edgeXY.y),rad+rad,0,fullWeightColor);
    drawLineY(ivec2(edgeXY.x,bounds.y+(bounds.y&1)),rad+rad,0,fullWeightColor);

    drawRectangle(bounds,fullWeightColor,1);
}

//reference implementation
void doBlurCircleExpensive(){
    int rad = clamp(int(radius),0,MAX_RAD);
    int radSquared = rad*rad;
    writeColorI/=quantizedCircleArea(rad);

    for(int y=-rad; y<=rad; y++){
        int xRange = int(sqrt(radSquared-y*y));
        for (int x=-xRange; x<=xRange; x++){
            write(ivec2(x+samplePos.x, y+samplePos.y), ivec2(0),writeColorI);
        }
    }
}

void doBlurCircle(){
    //veeeeery rough approximation, but i do still kinda like the pixely look

}


void doTheBlurForOneColor(){
    if(radius<=0.501){
        write(samplePos, ivec2(0),writeColorI);
        return;
    }

    radius = clamp(radius,0.5,MAX_RAD-0.5);

    doBlurSquare();
}

uniform float frameTimeCounter;

void main(){
    ivec2 texSize = textureSize(colortex0,0);
    pageSize = texSize.x;


    for(int i=0; i<3; i++){
        pageOffset = i*pageSize;
        #ifdef DOF2_TEST_PATTERN
        debugNum = i;
        #endif

        initBuffer();
        barrier();

        ivec2 scanAreaStart = ivec2(-MAX_RAD);
        ivec2 scanAreaEndExclusive = ivec2(SIZE+MAX_RAD);
//        scanAreaStart=ivec2(0);
//        scanAreaEndExclusive=ivec2(SIZE);
        int wrap = scanAreaEndExclusive.y-scanAreaStart.y;
        const int maxIndex = (SIZE+2*MAX_RAD)*(SIZE+2*MAX_RAD);

        for(int id = int(gl_LocalInvocationIndex);id<maxIndex;id+=SIZE*SIZE){
            samplePos = ivec2(id/wrap, id%wrap)+scanAreaStart;
            ivec2 globalPos = samplePos + ivec2(gl_WorkGroupID.xy*SIZE);
            if(globalPos.x<0 || globalPos.y<0 || globalPos.x>=texSize.x || globalPos.y>=texSize.y)
                continue;

            writeColorI = uint(texelFetch(colortex0,globalPos,0).rgb[i]*0x00800000u);
            radius=texelFetch(colortex12,globalPos,0).y;

            #ifdef DOF_ABBERATION
            radius = min(radius ,MAX_RAD-0.5);
            radius = max(0.5 ,radius-2*i);
            #endif

            doTheBlurForOneColor();
//            drawLineX(ivec2(-3,SIZE+SIZE-int(4*frameTimeCounter)),SIZE+SIZE,0,writeColorI);
//            drawLineY(ivec2(SIZE-int(4*frameTimeCounter),-3),SIZE+SIZE,0,0x00400);
        }




        barrier();
        flushBuffer();

        if(i<2)
            barrier();
    }
}