#version 430
#include "lib/settings.glsl"


#define SIZE 32
#define MAX_RAD 48
#define MAX_LEVEL 4
#define POS_OFFSET 1
#define SCALEFACTOR 0x01000000u

const vec2 workGroupsRender = vec2(1.0,1.0);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;


layout (rgba32ui) uniform writeonly restrict uimage2D dynamicDofImg;
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
    value= uvec3(0);
    ivec2 pos = ivec2((gl_LocalInvocationID.x+SIZE)>>1, gl_LocalInvocationID.y+SIZE*(gl_LocalInvocationID.x&1u));

    if(pos.y>=POS_OFFSET){
        for (int level=0;level<=MAX_LEVEL;level++){
            ivec2 levelPos = ivec2(pos.x>>level,pos.y)-POS_OFFSET;
            value+=uvec3(
                thebufferrrR[levelPos.x][levelPos.y],
                thebufferrrG[levelPos.x][levelPos.y],
                thebufferrrB[levelPos.x][levelPos.y]
            );
        }

        pos.x<<=1;
        pos-=POS_OFFSET;

        atomicAdd(thebufferrrR[pos.x][pos.y], value.x);
        atomicAdd(thebufferrrG[pos.x][pos.y], value.y);
        atomicAdd(thebufferrrB[pos.x][pos.y], value.z);

        atomicAdd(thebufferrrR[1+pos.x][pos.y], value.x);
        atomicAdd(thebufferrrG[1+pos.x][pos.y], value.y);
        atomicAdd(thebufferrrB[1+pos.x][pos.y], value.z);
    }

    barrier();

    value= uvec3(0);
    pos = ivec2(gl_LocalInvocationID.x+SIZE, gl_LocalInvocationID.y+SIZE);
    for (int level=0;level<=MAX_LEVEL;level++){
        ivec2 levelPos = ivec2(pos.x,pos.y>>level)-POS_OFFSET;
        value+=uvec3(
            thebufferrrR[levelPos.x][levelPos.y],
            thebufferrrG[levelPos.x][levelPos.y],
            thebufferrrB[levelPos.x][levelPos.y]
        );
    }

    imageStore(dynamicDofImg,ivec2(gl_WorkGroupID.xy*SIZE+gl_LocalInvocationID.xy),uvec4(value,0));
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

void drawRectangle(ivec4 bounds){
    bounds.xy=max(bounds.xy,0);
    bounds.zw=min(bounds.zw,SIZE-1);
    if(bounds.z<bounds.x || bounds.w<bounds.y)return;

    bounds+=SIZE;

    while(bounds.y<=bounds.w){
        int awa = bounds.y|0xffffff00;
        awa |= awa<<4;
        awa |= awa<<2;
        awa |= awa<<1;
        int levelY=min(MAX_LEVEL,min(bitCount(~awa),int(log2(1+bounds.w-bounds.y))));
        for(int x=bounds.x;x<=bounds.z;){
            awa = x|0xffffff00;
            awa |= awa<<4;
            awa |= awa<<2;
            awa |= awa<<1;
            int levelX=min(MAX_LEVEL,min(bitCount(~awa),int(log2(1+bounds.z-x))));
            bufferDirectWrite(ivec2(x>>levelX, bounds.y>>levelY));
            x+=1<<levelX;
        }
        bounds.y+=1<<levelY;
    }
}



void doBlurSquare(){
    int rad = clamp(int(radius+0.5),0,MAX_RAD);
    //min xy, max xy
    ivec4 bounds = ivec4(samplePos.xyxy);
    bounds.xy-=rad;
    bounds.zw+=rad;


#define smoothDofEdges
//#define smoothDofEdgesNew

#ifdef smoothDofEdges
    uvec3 weightedColor = uvec3(color/(4.0*radius*radius));

    #ifdef smoothDofEdgesNew
    int radLevel = clamp(int(log2(rad+rad+1))-1,0,30);
//    radLevel=2;
    color = (color-(weightedColor*(2*rad-1)*(2*rad-1)))/(4<<radLevel);
    write(ivec2(((bounds.x)>>radLevel)+1,bounds.w),ivec2(radLevel,0));
    write(ivec2(((bounds.x)>>radLevel)+1,bounds.y),ivec2(radLevel,0));
    write(ivec2(bounds.x,((bounds.y)>>radLevel)+1),ivec2(0,radLevel));
    write(ivec2(bounds.z,((bounds.y)>>radLevel)+1),ivec2(0,radLevel));
    #else

    int maxEdgeEffort = 3; //1 to rad*2
    maxEdgeEffort=min(maxEdgeEffort,rad);

    color = (color-(weightedColor*(2*rad-1)*(2*rad-1)))/(maxEdgeEffort<<2);

    for (int i=0; i<maxEdgeEffort; i++){
        int offset = (rad*i<<1)/maxEdgeEffort;
        write(bounds.xy+ivec2(0, offset), ivec2(0));
        write(bounds.xw+ivec2(offset, 0), ivec2(0));
        write(bounds.zy-ivec2(offset, 0), ivec2(0));
        write(bounds.zw-ivec2(0, offset), ivec2(0));
    }
    #endif

    color=weightedColor;
    bounds.xy++;
    bounds.zw--;
#else
    color/=(rad*2+1)*(rad*2+1);
#endif


    drawRectangle(bounds);
}


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