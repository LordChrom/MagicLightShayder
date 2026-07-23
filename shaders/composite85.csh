#version 430
#include "lib/settings.glsl"


#define SIZE 32
#define MAX_RAD 10
#define MAX_LEVEL 4
#define POS_OFFSET 1

#define SCALEFACTOR 0x01000000u

const vec2 workGroupsRender = vec2(1.0,1.0);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;


layout (rgba32ui) uniform restrict uimage2D dynamicDofImg;
#define BUFFERSIZE (SIZE+SIZE-POS_OFFSET)
shared uint[BUFFERSIZE][BUFFERSIZE] thebufferrrR;
shared uint[BUFFERSIZE][BUFFERSIZE] thebufferrrG;
shared uint[BUFFERSIZE][BUFFERSIZE] thebufferrrB;


uniform sampler2D colortex0;
uniform sampler2D colortex12;

uvec3 color;
ivec2 samplePos;
float radius;

void initBuffer(){
    for(int i=0;i<4;i++){
        int id = int(gl_LocalInvocationIndex<<2)+i;
        ivec2 pos = ivec2(id/(2*SIZE),id%(2*SIZE));

        thebufferrrR[pos.x][pos.y]=0u;
        thebufferrrG[pos.x][pos.y]=0u;
        thebufferrrB[pos.x][pos.y]=0u;
    }
}

void flushBuffer(){
    uvec3 value;
    for(int i=0; i<2; i++){
        value= uvec3(0);
        ivec2 pos = ivec2(gl_LocalInvocationID.x+SIZE, gl_LocalInvocationID.y+SIZE*i);
        for (int level=0;level<=MAX_LEVEL;level++){
            value+=uvec3(
                thebufferrrR[pos.x-POS_OFFSET][pos.y-POS_OFFSET],
                thebufferrrG[pos.x-POS_OFFSET][pos.y-POS_OFFSET],
                thebufferrrB[pos.x-POS_OFFSET][pos.y-POS_OFFSET]
            );
            pos.x>>=1;
        }
        pos.x = int(gl_LocalInvocationID.x+SIZE);
        thebufferrrR[pos.x-POS_OFFSET][pos.y-POS_OFFSET]=value.x;
        thebufferrrG[pos.x-POS_OFFSET][pos.y-POS_OFFSET]=value.y;
        thebufferrrB[pos.x-POS_OFFSET][pos.y-POS_OFFSET]=value.z;
    }

    barrier();

    value= uvec3(0);
    ivec2 pos = ivec2(gl_LocalInvocationID.x+SIZE, gl_LocalInvocationID.y+SIZE);
    for (int level=0;level<=MAX_LEVEL;level++){
        value+=uvec3(
            thebufferrrR[pos.x-POS_OFFSET][pos.y-POS_OFFSET],
            thebufferrrG[pos.x-POS_OFFSET][pos.y-POS_OFFSET],
            thebufferrrB[pos.x-POS_OFFSET][pos.y-POS_OFFSET]
        );
        pos.y>>=1;
    }

    pos = ivec2(gl_WorkGroupID.xy*SIZE+gl_LocalInvocationID.xy);
    if(value!=uvec3(0))
        imageStore(dynamicDofImg,pos,uvec4(value,0));
}

void bufferDirectWrite(ivec2 pos){
    pos-=POS_OFFSET;
    atomicAdd(thebufferrrR[pos.x][pos.y],color[0]);
    atomicAdd(thebufferrrG[pos.x][pos.y],color[1]);
    atomicAdd(thebufferrrB[pos.x][pos.y],color[2]);
}

void write(ivec2 pos,ivec2 level){
    if((pos.x>=(SIZE>>level.x))||(pos.y>=(SIZE>>level.y))||(pos.x<0) || (pos.y<0))
        return;

    pos+=ivec2(SIZE)>>level;
    bufferDirectWrite(pos);
}


//void drawLine(ivec2 pos, ivec2 step, int steps, int level){
//    for(int i=0; i<steps; i++){
//        write(pos,ivec2(level));
//        pos+=step;
//    }
//}

//void drawLineX(ivec2 bounds, int y, int levelY){
////    bounds.x=max(bounds.x,0);
////    bounds.y=min(bounds.y,SIZE-1);
////    bounds+=SIZE;
//
//    if((y>=(SIZE>>levelY))|| (y<0))
//        return;
//
//    y+=SIZE>>levelY;
//
//    for(int level = 0; level < MAX_LEVEL; level++){
//        uint levelBits = (1<<level)-1;
//        ivec2 newBounds = (bounds+SIZE+ivec2(levelBits,-levelBits))>>level;
//        if(newBounds.y<newBounds.x)return;
//
//
//        if (bool(newBounds.x  &1))
//            bufferDirectWrite(ivec2(newBounds.x,y));
//
//        if (bool((~newBounds.y)&1))
//            bufferDirectWrite(ivec2(newBounds.y,y));
//    }
//
//
//    uint levelBits = (1<<MAX_LEVEL)-1;
//    ivec2 newBounds = (bounds+SIZE+ivec2(levelBits,-levelBits))>>MAX_LEVEL;
//    for(int x=newBounds.x;x<=newBounds.y;x++)
//        bufferDirectWrite(ivec2(x,y));
//}

void drawRectangle(ivec4 bounds){
    bounds.xy=max(bounds.xy,0);
    bounds.zw=min(bounds.zw,SIZE-1);
    if(bounds.z<bounds.x || bounds.w<bounds.y)return;

    bounds+=SIZE;

    int[8] xSpots;
    int numXSpots = 0;

    for(int level= 0; level<= MAX_LEVEL; level++){
        if(bounds.x>bounds.z) break;

        if (bool(bounds.x  &1))
            xSpots[numXSpots++]=bounds.x;
        if (bool((~bounds.z)&1))
            xSpots[numXSpots++]=bounds.z;

        bounds.x++;
        bounds.z--;
        bounds.xz>>=1;
    }


    for(int level= 0; level<= MAX_LEVEL; level++){
        if(bounds.y>bounds.w) return;

        for (int i=0;i<numXSpots;i++){
            int x = xSpots[i];
            if(bool(bounds.y  &1))
                bufferDirectWrite(ivec2(x, bounds.y));
            if(bool((~bounds.w)&1))
                bufferDirectWrite(ivec2(x, bounds.w));
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
void doBlurSquareExpensive(){
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
            write(ivec2(x, y), ivec2(0));
        }
    }
}

void doBlurSquare(){
    int rad = clamp(int(radius+0.5),0,MAX_RAD);
    int actualArea = (rad+rad+1);
    actualArea*=actualArea;

//    if(fullWeightColor<0x10)fullWeightColor=0;

    //min xy, max xy
    ivec4 bounds = ivec4(samplePos.xyxy);
    bounds.xy-=rad;
    bounds.zw+=rad;

    uvec3 weightedColor = uvec3(color/(4.0*radius*radius));

    #if 1

    int maxEdgeEffort = 3; //1 to rad*2
    maxEdgeEffort=min(maxEdgeEffort,rad);

    color = (color-(weightedColor*(2*rad-1)*(2*rad-1)))/(maxEdgeEffort<<2);

//    int radLevel = int(log2(rad+1));
//    write(ivec2(((bounds.x)>>radLevel)+1,bounds.w),ivec2(radLevel,0));
//    write(ivec2(((bounds.x)>>radLevel)+1,bounds.y),ivec2(radLevel,0));
//    write(ivec2(bounds.x,((bounds.y)>>radLevel)+1),ivec2(0,radLevel));
//    write(ivec2(bounds.z,((bounds.y)>>radLevel)+1),ivec2(0,radLevel));

    for (int i=0; i<maxEdgeEffort; i++){
        int offset = (rad*i<<1)/maxEdgeEffort;
        write(bounds.xy+ivec2(0, offset), ivec2(0));
        write(bounds.xw+ivec2(offset, 0), ivec2(0));
        write(bounds.zy-ivec2(offset, 0), ivec2(0));
        write(bounds.zw-ivec2(0, offset), ivec2(0));
    }

    bounds.xy++;
    bounds.zw--;
    #endif
    color = weightedColor;

//    if(min(min(color.x,color.y),color.z)<=100)return;



    drawRectangle(bounds);
}


void doTheBlurForOneColor(){

}

uniform float frameTimeCounter;

void main(){
    initBuffer();
    barrier();

    ivec2 scanAreaStart = max(ivec2(-MAX_RAD),-ivec2(gl_WorkGroupID.xy*SIZE));
    ivec2 scanAreaEndExclusive = min(ivec2(SIZE+MAX_RAD),textureSize(colortex0,0)-ivec2(gl_WorkGroupID.xy*SIZE));
    int wrap = scanAreaEndExclusive.y-scanAreaStart.y;
    int id = wrap*(scanAreaEndExclusive.x-scanAreaStart.x)-int(gl_LocalInvocationIndex);

    for(;id>=0;id-=SIZE*SIZE){
        samplePos = ivec2(id/wrap, id%wrap)+scanAreaStart;

        radius=texelFetch(colortex12,samplePos + ivec2(gl_WorkGroupID.xy*SIZE),0).y;

        int rad = clamp(int(radius+0.5),0,MAX_RAD);
        if (samplePos.x+rad<0 || samplePos.y+rad<0 || samplePos.x-rad>=SIZE || samplePos.y-rad>=SIZE)
            continue;


        color = uvec3(texelFetch(colortex0,samplePos + ivec2(gl_WorkGroupID.xy*SIZE),0).rgb*SCALEFACTOR);

        if(radius<=0.501){
            write(samplePos, ivec2(0));
            continue;
        }

        radius = clamp(radius,0.5,MAX_RAD-0.5);

        doBlurSquare();
    }

    barrier();
    flushBuffer();
}