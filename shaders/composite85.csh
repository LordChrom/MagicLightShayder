#version 430
#include "lib/settings.glsl"


#define SIZE 32
#define MAX_RAD 10
#define MAX_LEVEL 4


const vec2 workGroupsRender = vec2(1.0,1.0);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;



layout (rgba32ui) uniform restrict uimage2D dynamicDofImg;
shared uint[SIZE+SIZE][SIZE+SIZE][3] thebufferrrr;


uniform sampler2D colortex0;
uniform sampler2D colortex12;

ivec2 samplePos;
float radius;

void initBuffer(){
    int id = int(gl_LocalInvocationIndex);
    id<<=2;
    ivec2 pos = ivec2(id/(2*SIZE),id%(2*SIZE));
    for(int i=0;i<4;i++){
        for(int j=0;j<3;j++){
            thebufferrrr[pos.x][pos.y+i][j]=0u;
        }
    }
}

void flushBuffer(){
    uvec3 value = uvec3(0);

    ivec2 level;
    for(level.x=0; level.x<=MAX_LEVEL;level.x++){
        for(level.y=0; level.y<=MAX_LEVEL;level.y++){
            ivec2 levelPos = ivec2(gl_LocalInvocationID.xy+SIZE)>>level;
            for(int i=0;i<3;i++){
                #ifdef DOF2_TEST_PATTERN
                if(bool(((level.x+level.y)%7)&(1<<i)))
                    continue;
                #endif
                value[i]+=thebufferrrr[levelPos.x][levelPos.y][i];
            }
        }
    }

    ivec2 pos = ivec2(gl_WorkGroupID.xy*SIZE+gl_LocalInvocationID.xy);
    if(value!=uvec3(0))
        imageStore(dynamicDofImg,pos,uvec4(value,0));
}

void bufferDirectWrite(ivec2 pos, uvec3 color){
    for(int i=0;i<3;i++)
        atomicAdd(thebufferrrr[pos.x][pos.y][i],color[i]);
}

void write(ivec2 pos,ivec2 level, uvec3 color){
    if((pos.x>=(SIZE>>level.x))||(pos.y>=(SIZE>>level.y))||(pos.x<0) || (pos.y<0))
        return;

    pos+=ivec2(SIZE)>>level;
    bufferDirectWrite(pos,color);
}


void drawLine(ivec2 pos, ivec2 step, int steps, int level, uvec3 data){
    for(int i=0; i<steps; i++){
        write(pos,ivec2(level),data);
        pos+=step;
    }
}

void drawLineX(ivec2 bounds, int y, int levelY, uvec3 color){

//    for(int x=bounds.x;x<=bounds.y;x++){
//        write(ivec2(x,y),ivec2(0,levelY),color);
//    }

    if((y>=(SIZE>>levelY))|| (y<0))
        return;

    y+=SIZE>>levelY;

    int level;


    for(level = 0; level < MAX_LEVEL; level++){
        if(bounds.y<bounds.x)return;
        if(bounds.y-bounds.x<=1){
            break;
        }
        int levelOffset = SIZE>>level;

        if (bool(bounds.x  &1) && !((bounds.x>=levelOffset)||(bounds.x<0)))
            bufferDirectWrite(ivec2(bounds.x+levelOffset,y), color);

        if (bool((~bounds.y)&1) && !((bounds.y>=levelOffset)||(bounds.y<0)))
            bufferDirectWrite(ivec2(bounds.y+levelOffset,y), color);

        bounds.x++;
        bounds.y--;
        bounds>>=1;
    }

    if((y>=2*(SIZE>>levelY))||(y<SIZE>>levelY))
        return;

    bounds.x=max(bounds.x,0);
    bounds.y=min(bounds.y,(SIZE>>level)-1);
    bounds+=(SIZE>>level);

    for(int x=bounds.x;x<=bounds.y;x++)
        bufferDirectWrite(ivec2(x,y), color);
}

void drawRectangle(ivec4 bounds, uvec3 color){
    int level;


    for(level = 0; level < MAX_LEVEL; level++){
        if(bounds.w<bounds.y)return;
        if(bounds.w-bounds.y<=1){
            break;
        }
        int levelOffset = SIZE>>level;

        if (bool(bounds.y  &1))
            drawLineX(bounds.xz,bounds.y,level,color);

        if (bool((~bounds.w)&1))
            drawLineX(bounds.xz,bounds.w,level,color);

        bounds.y++;
        bounds.w--;
        bounds.yw>>=1;
    }

    bounds.y=max(bounds.y,0);
    bounds.w=min(bounds.w,(SIZE>>level)-1);

    for(int y=bounds.y;y<=bounds.w;y++){
        drawLineX(bounds.xz,y,level,color);
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
void doBlurSquareExpensive(uvec3 color){
    int rad = clamp(int(radius+0.5),0,MAX_RAD);

    int actualArea = (rad+rad+1);
    actualArea*=actualArea;
    float desiredArea = 4.0*radius*radius;
    int edgePixels = rad<<3;
    float edgeWeight=1-(actualArea-desiredArea)/edgePixels;

    uvec3 fullWeightColor = uvec3(color/desiredArea);
    uvec3 edgeWeightedColor = uvec3(fullWeightColor*edgeWeight);

    for(int x=-rad; x<=rad; x++){
        for (int y=-rad; y<=rad; y++){
            write(ivec2(x+samplePos.x, y+samplePos.y), ivec2(0),
                ((max(abs(x),abs(y))==rad))?edgeWeightedColor:fullWeightColor
            );
        }
    }
}

void doBlurSquare(uvec3 color){
    int rad = clamp(int(radius+0.5),0,MAX_RAD);
    int actualArea = (rad+rad+1);
    actualArea*=actualArea;

    float desiredArea = 4.0*radius*radius;
    uvec3 fullWeightColor = uvec3(color/desiredArea);
//    if(fullWeightColor<0x10)fullWeightColor=0;


    ivec4 miniBounds = ivec4(samplePos.xyxy);
    miniBounds.xy-=rad;
    miniBounds.zw+=rad;

    int maxEdgeEffort = 3; //1 to rad*2
    maxEdgeEffort=min(maxEdgeEffort,rad+rad);

    int edgePixels = rad<<3;
    float edgeWeight=1-(actualArea-desiredArea)/edgePixels;
    uvec3 edgeWeightedColor = (color-(fullWeightColor*(2*rad-1)*(2*rad-1)))/(maxEdgeEffort<<2);

    for (int i=0; i<maxEdgeEffort; i++){
        int offset = (rad*i<<1)/maxEdgeEffort;
        write(miniBounds.xy+ivec2(0, offset), ivec2(0), edgeWeightedColor);
        write(miniBounds.xw+ivec2(offset, 0), ivec2(0), edgeWeightedColor);
        write(miniBounds.zy-ivec2(offset, 0), ivec2(0), edgeWeightedColor);
        write(miniBounds.zw-ivec2(0, offset), ivec2(0), edgeWeightedColor);
    }
    rad--;

    if(fullWeightColor==0)return;

    //min xy, max xy
    ivec4 bounds = ivec4(samplePos.xyxy);
    bounds.xy-=rad;
    bounds.zw+=rad;

    drawRectangle(bounds,fullWeightColor);
}

//reference implementation
void doBlurCircleExpensive(uvec3 color){
    int rad = clamp(int(radius),0,MAX_RAD);
    int radSquared = rad*rad;
    color/=quantizedCircleArea(rad);

    for(int y=-rad; y<=rad; y++){
        int xRange = int(sqrt(radSquared-y*y));
        for (int x=-xRange; x<=xRange; x++){
            write(ivec2(x+samplePos.x, y+samplePos.y), ivec2(0),color);
        }
    }
}

void doBlurCircle(){
    //veeeeery rough approximation, but i do still kinda like the pixely look

}


void doTheBlurForOneColor(uvec3 color){
    if(radius<=0.501){
        write(samplePos, ivec2(0),color);
        return;
    }

    radius = clamp(radius,0.5,MAX_RAD-0.5);

    doBlurSquare(color);
}

uniform float frameTimeCounter;

void main(){
    initBuffer();
    barrier();

    ivec2 scanAreaStart = max(ivec2(-MAX_RAD),-ivec2(gl_WorkGroupID.xy*SIZE));
    ivec2 scanAreaEndExclusive = min(ivec2(SIZE+MAX_RAD),textureSize(colortex0,0)-ivec2(gl_WorkGroupID.xy*SIZE));
    int wrap = scanAreaEndExclusive.y-scanAreaStart.y;
    const int maxIndex = (SIZE+2*MAX_RAD)*(SIZE+2*MAX_RAD);

    for(int id = int(gl_LocalInvocationIndex);id<maxIndex;id+=SIZE*SIZE){
        samplePos = ivec2(id/wrap, id%wrap)+scanAreaStart;
        ivec2 globalPos = samplePos + ivec2(gl_WorkGroupID.xy*SIZE);

        uvec3 color = uvec3(texelFetch(colortex0,globalPos,0).rgb*0x00800000u);
        radius=texelFetch(colortex12,globalPos,0).y;

        int rad = clamp(int(radius),0,MAX_RAD);

        if(samplePos.x+rad<scanAreaStart.x || samplePos.y+rad<scanAreaStart.y || samplePos.x-rad>=scanAreaEndExclusive.x || samplePos.y-rad>=scanAreaEndExclusive.y)
            continue;

        doTheBlurForOneColor(color);
    }

    barrier();
    flushBuffer();
}