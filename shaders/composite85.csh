#version 430
#include "lib/settings.glsl"


#define SIZE 32
#define MAX_RAD 96
#define MAX_LEVEL 7


const vec2 workGroupsRender = vec2(1.0,1.0);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;



layout (rgba32ui) uniform restrict uimage2D dynamicDofImg;
shared uint[SIZE+SIZE][SIZE+SIZE][3] thebufferrrr;


uniform sampler2D colortex0;
uniform sampler2D colortex12;

ivec2 samplePos;
float radius;

void initBuffer(){

    for(int i=0;i<12;i++){
        int id = int(gl_LocalInvocationIndex)+SIZE*SIZE*i;
        ivec3 pos = ivec3(
            id/(6*SIZE),
            (id/3)%(2*SIZE),
            id%3
        );
        thebufferrrr[pos.x][pos.y][pos.z]=0u;
    }
}

void flushBuffer(){
    uvec3 value;
    for(int i=0; i<2; i++){
        value= uvec3(0);
        ivec2 pos = ivec2(gl_LocalInvocationID.x+SIZE, gl_LocalInvocationID.y+SIZE*i);
        for (int level=0;level<=MAX_LEVEL;level++){
            value+=uvec3(
                thebufferrrr[pos.x][pos.y][0],
                thebufferrrr[pos.x][pos.y][1],
                thebufferrrr[pos.x][pos.y][2]
            );
            pos.x>>=1;
        }
        pos.x = int(gl_LocalInvocationID.x+SIZE);
        thebufferrrr[pos.x][pos.y][0]=value.x;
        thebufferrrr[pos.x][pos.y][1]=value.y;
        thebufferrrr[pos.x][pos.y][2]=value.z;
    }

    barrier();

    value= uvec3(0);
    ivec2 pos = ivec2(gl_LocalInvocationID.x+SIZE, gl_LocalInvocationID.y+SIZE);
    for (int level=0;level<=MAX_LEVEL;level++){
        value+=uvec3(
            thebufferrrr[pos.x][pos.y][0],
            thebufferrrr[pos.x][pos.y][1],
            thebufferrrr[pos.x][pos.y][2]
        );
        pos.y>>=1;
    }

    pos = ivec2(gl_WorkGroupID.xy*SIZE+gl_LocalInvocationID.xy);
    if(value!=uvec3(0))
        imageStore(dynamicDofImg,pos,uvec4(value,0));
}

void bufferDirectWrite(ivec2 pos, uvec3 color){
    atomicAdd(thebufferrrr[pos.x][pos.y][0],color[0]);
    atomicAdd(thebufferrrr[pos.x][pos.y][1],color[1]);
    atomicAdd(thebufferrrr[pos.x][pos.y][2],color[2]);
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
//    bounds.x=max(bounds.x,0);
//    bounds.y=min(bounds.y,SIZE-1);
//    bounds+=SIZE;

    if((y>=(SIZE>>levelY))|| (y<0))
        return;

    y+=SIZE>>levelY;

    for(int level = 0; level < MAX_LEVEL; level++){
        uint levelBits = (1<<level)-1;
        ivec2 newBounds = (bounds+SIZE+ivec2(levelBits,-levelBits))>>level;
        if(newBounds.y<newBounds.x)return;


        if (bool(newBounds.x  &1))
            bufferDirectWrite(ivec2(newBounds.x,y), color);

        if (bool((~newBounds.y)&1))
            bufferDirectWrite(ivec2(newBounds.y,y), color);
    }


    uint levelBits = (1<<MAX_LEVEL)-1;
    ivec2 newBounds = (bounds+SIZE+ivec2(levelBits,-levelBits))>>MAX_LEVEL;
    for(int x=newBounds.x;x<=newBounds.y;x++)
        bufferDirectWrite(ivec2(x,y), color);
}

void drawRectangle(ivec4 bounds, uvec3 color){
    bounds.xy=max(bounds.xy,0);
    bounds.zw=min(bounds.zw,SIZE-1);
    if(bounds.z<bounds.x || bounds.w<bounds.y)return;

    bounds+=SIZE;

    int[8] xSpots;
    int numXSpots = 0;

    for(int level= 0; level< MAX_LEVEL; level++){
        if(bounds.x>bounds.z) break;

        if (bool(bounds.x  &1))
            xSpots[numXSpots++]=bounds.x;
        if (bool((~bounds.z)&1))
            xSpots[numXSpots++]=bounds.z;

        bounds.x++;
        bounds.z--;
        bounds.xz>>=1;
    }


    for(int level= 0; level< MAX_LEVEL; level++){
        if(bounds.y>bounds.w) return;

        for (int i=0;i<numXSpots;i++){
            int x = xSpots[i];
            if(bool(bounds.y  &1))
                bufferDirectWrite(ivec2(x, bounds.y), color);
            if(bool((~bounds.w)&1))
                bufferDirectWrite(ivec2(x, bounds.w), color);
        }
        bounds.y++;
        bounds.w--;
        bounds.yw>>=1;
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

    //min xy, max xy
    ivec4 bounds = ivec4(samplePos.xyxy);
    bounds.xy-=rad;
    bounds.zw+=rad;

    #if 1
    int maxEdgeEffort = 3; //1 to rad*2
    maxEdgeEffort=min(maxEdgeEffort,rad+rad);

    int edgePixels = rad<<3;
    float edgeWeight=1-(actualArea-desiredArea)/edgePixels;
    uvec3 edgeWeightedColor = (color-(fullWeightColor*(2*rad-1)*(2*rad-1)))/(maxEdgeEffort<<2);

    for (int i=0; i<maxEdgeEffort; i++){
        int offset = (rad*i<<1)/maxEdgeEffort;
        write(bounds.xy+ivec2(0, offset), ivec2(0), edgeWeightedColor);
        write(bounds.xw+ivec2(offset, 0), ivec2(0), edgeWeightedColor);
        write(bounds.zy-ivec2(offset, 0), ivec2(0), edgeWeightedColor);
        write(bounds.zw-ivec2(0, offset), ivec2(0), edgeWeightedColor);
    }
    bounds.xy++;
    bounds.zw--;
    #endif

    if(fullWeightColor==0)return;



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
    const int maxIndex = wrap*(scanAreaEndExclusive.x-scanAreaStart.x);

    for(int id = int(gl_LocalInvocationIndex);id<maxIndex;id+=SIZE*SIZE){
        samplePos = ivec2(id/wrap, id%wrap)+scanAreaStart;
        ivec2 globalPos = samplePos + ivec2(gl_WorkGroupID.xy*SIZE);

        uvec3 color = uvec3(texelFetch(colortex0,globalPos,0).rgb*0x00800000u);
        radius=texelFetch(colortex12,globalPos,0).y;

        int rad = clamp(int(radius+0.5),0,MAX_RAD);

        if (samplePos.x+rad<0 || samplePos.y+rad<0 || samplePos.x-rad>=SIZE || samplePos.y-rad>=SIZE)
            continue;

        doTheBlurForOneColor(color);
    }

    barrier();
    flushBuffer();
}