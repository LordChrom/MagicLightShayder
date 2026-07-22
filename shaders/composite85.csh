#version 430
#include "lib/settings.glsl"


#define SIZE 8
#define MAX_RAD 32
#define MAX_LEVEL 5


const vec2 workGroupsRender = vec2(1.0,1.0);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;



layout (r32ui) uniform restrict uimage2D dynamicDofImg;


uniform sampler2D colortex0;
uniform sampler2D colortex12;

ivec2 bufferSize;
ivec2 samplePos;
float radius;

void bufferDirectWrite(ivec2 pos, uvec3 color){
    for(int i=0; i<3; i++){
        imageAtomicAdd(dynamicDofImg,pos,color[i]);
        pos.x+=bufferSize.x<<1;
    }
}

void write(ivec2 pos,ivec2 level, uvec3 color){
    if((pos.x>=(bufferSize.x>>level.x))||(pos.y>=(bufferSize.y>>level.y))||(pos.x<0) || (pos.y<0))
        return;

    pos+=bufferSize>>level;
    bufferDirectWrite(pos,color);
}

void drawLineX(ivec2 bounds, int y, int levelY, uvec3 color){
    if((y>=(bufferSize.y>>levelY))|| (y<0))
        return;

    y+=bufferSize.y>>levelY;
    bounds+=bufferSize.x;


    for(int level = 0; level <= MAX_LEVEL; level++){
        if(bounds.y<bounds.x)return;


        if (bool(bounds.x  &1))
            bufferDirectWrite(ivec2(bounds.x,y),color);

        if (bool((~bounds.y)&1))
            bufferDirectWrite(ivec2(bounds.y,y),color);

        bounds.x++;
        bounds.y--;
        bounds>>=1;

    }
}

void drawRectangle(ivec4 bounds, uvec3 color){
    bounds.xy=max(bounds.xy,0);
    bounds.zw=min(bounds.zw,bufferSize-1);
    if(bounds.z<bounds.x || bounds.w<bounds.y)return;

    for(int level = 0; level <= MAX_LEVEL; level++){
        if(bounds.w<bounds.y)return;

        if (bool(bounds.y  &1))
            drawLineX(bounds.xz,bounds.y,level,color);

        if (bool((~bounds.w)&1))
            drawLineX(bounds.xz,bounds.w,level,color);

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
    bufferSize=((textureSize(colortex0,0)>>MAX_LEVEL)+1)<<MAX_LEVEL;
    samplePos = ivec2(gl_WorkGroupID.xy*SIZE+gl_LocalInvocationID.xy);

    uvec3 color = uvec3(texelFetch(colortex0,samplePos,0).rgb*0x00800000u);
    radius=texelFetch(colortex12,samplePos,0).y;

    int rad = clamp(int(radius),0,MAX_RAD);

    doTheBlurForOneColor(color);
}