#version 430
#include "lib/settings.glsl"


#define SIZE 16
#define SIZE_X SIZE
#define SIZE_Y SIZE
#define MAX_RAD 10
#define MAX_LEVEL 5


const vec2 workGroupsRender = vec2(1.0,1.0);
layout (local_size_x = SIZE_X, local_size_y = SIZE_Y, local_size_z = 1) in;



layout (r32ui) uniform restrict uimage2D dynamicDofImg;


uniform sampler2D colortex0;
uniform sampler2D colortex12;

uvec3 color;
int i;
ivec2 bufferSize;
float radius;

ivec2 getSamplePos(){
    return ivec2(gl_WorkGroupID.x*SIZE_X+gl_LocalInvocationID.x,gl_WorkGroupID.y*SIZE_Y+gl_LocalInvocationID.y);
}

void bufferDirectWrite(ivec2 pos, uvec3 col){
    imageAtomicAdd(dynamicDofImg,pos,col.r);
    imageAtomicAdd(dynamicDofImg,ivec2(pos.x+(bufferSize.x<<1),pos.y),col.g);
    imageAtomicAdd(dynamicDofImg,ivec2(pos.x+(bufferSize.x<<2),pos.y),col.b);
}

void bufferDirectWrite(ivec2 pos){
    bufferDirectWrite(pos,color);
}

void drawLineX(ivec2 bounds, int y, int levelY){
    if((y>=(bufferSize.y>>levelY))|| (y<0))
        return;

    y+=bufferSize.y>>levelY;
    bounds+=bufferSize.x;


    for(int level = 0; level <= MAX_LEVEL && bounds.x<=bounds.y; level++){
        if (bool(bounds.x  &1))
            bufferDirectWrite(ivec2(bounds.x,y));

        if (bool((~bounds.y)&1))
            bufferDirectWrite(ivec2(bounds.y,y));

        bounds.x++;
        bounds.y--;
        bounds>>=1;

    }
}

void drawRectangle(ivec4 bounds){
    bounds.xy=max(bounds.xy,0);
    bounds.zw=min(bounds.zw,bufferSize-1);
    if(bounds.z<bounds.x || bounds.w<bounds.y)return;

    for(int level = 0; level <= MAX_LEVEL && bounds.y<=bounds.w; level++){
        if (bool(bounds.y  &1))
            drawLineX(bounds.xz,bounds.y,level);

        if (bool((~bounds.w)&1))
            drawLineX(bounds.xz,bounds.w,level);

        bounds.y++;
        bounds.w--;
        bounds.yw>>=1;
    }
}



//int quantizedCircleArea(int rad){
//    int radSquared = rad*rad;
//    int ret = rad;
//    for(int y=1; y<=rad; y++){
//        ret+= int(sqrt(radSquared-y*y));
//    }
//    return (ret<<2)+1;
//}

void doBlurSquare(){
    int rad = clamp(int(radius+0.5),0,MAX_RAD);
    int actualArea = (rad+rad+1);
    actualArea*=actualArea;

    float desiredArea = 4.0*radius*radius;
    color = uvec3(color/desiredArea);
//    if(fullWeightColor<0x10)fullWeightColor=0;

    //min xy, max xy
    ivec4 bounds = getSamplePos().xyxy;
    bounds.xy=max(bounds.xy-rad,0);
    bounds.zw=min(bounds.zw+rad,bufferSize);

    #if 1
    int maxEdgeEffort = 3; //1 to rad*2
    maxEdgeEffort=min(maxEdgeEffort,rad+rad);

    int edgePixels = rad<<3;
    float edgeWeight=1-(actualArea-desiredArea)/edgePixels;
    uvec3 edgeWeightedColor = uvec3(color*((desiredArea-(2*rad-1)*(2*rad-1))/(maxEdgeEffort<<2)));

    bounds+=bufferSize.xyxy;
    for (int i=0; i<maxEdgeEffort; i++){
        int offset = (rad*i<<1)/maxEdgeEffort;
        bufferDirectWrite(bounds.xy+ivec2(0, offset), edgeWeightedColor);
        bufferDirectWrite(bounds.xw+ivec2(offset, 0), edgeWeightedColor);
        bufferDirectWrite(bounds.zy-ivec2(offset, 0), edgeWeightedColor);
        bufferDirectWrite(bounds.zw-ivec2(0, offset), edgeWeightedColor);
    }
    bounds-=bufferSize.xyxy;
    bounds.xy++;
    bounds.zw--;
    #endif


    drawRectangle(bounds);
}

//reference implementation
//void doBlurCircleExpensive(uint color){
//    int rad = clamp(int(radius),0,MAX_RAD);
//    int radSquared = rad*rad;
//    color/=quantizedCircleArea(rad);
//
//    ivec2 samplePos = ivec2(gl_WorkGroupID.xy*SIZE+gl_LocalInvocationID.xy);
//
//    for(int y=-rad; y<=rad; y++){
//        int xRange = int(sqrt(radSquared-y*y));
//        for (int x=-xRange; x<=xRange; x++){
//            write(ivec2(x+samplePos.x, y+samplePos.y), ivec2(0),color);
//        }
//    }
//}

//void doBlurCircle(){
//    //veeeeery rough approximation, but i do still kinda like the pixely look
//}

uniform float frameTimeCounter;

void main(){
    bufferSize=((textureSize(colortex0,0)>>MAX_LEVEL)+1)<<MAX_LEVEL;
    radius=texelFetch(colortex12,getSamplePos(),0).y;
    radius = clamp(radius,0.5,MAX_RAD-0.5);
    color = uvec3(texelFetch(colortex0,getSamplePos(),0).rgb*~0u);
//    if(radius<=10.501){
//        ivec2 samplePos = getSamplePos()+bufferSize;
//        for(int i=0; i<2; i++)
//            bufferDirectWrite(samplePos+ivec2((i<<2)*bufferSize.x,0), color[i]);
//        return;
//    }


        if(radius<=0.501){
            bufferDirectWrite(getSamplePos()+bufferSize);
            return;
        }
        doBlurSquare();
}