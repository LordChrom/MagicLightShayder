float depthTillChange(float value, float differential){
    return (1-fract(value*sign(differential)))/abs(differential);

}

float minDepthTillChange(vec3 value, vec3 differential){
    value = 1-fract(value*sign(differential));
    value/=abs(differential);
    return min(min(value.x,value.y),value.z);
}
const float nudge = 0.0001;


vec4 swrt_hitpos;
vec3 swrt_dir;
ivec3 swrt_areaPos;
float swrt_nextDepth = 0f;
uint swrt_translucency = 0u;
uint swrt_voxel = 0u;
uint swrt_distToFinal = 0u;
uint swrt_finalVoxel = 0u;
float swrt_internalHitDepth = 0f;



#ifdef SWRT_TEXTURED
uniform sampler2D blockAtlas;
vec4 texturedHit(vec3 samplePos, ivec3 areaPos){

    samplePos+=swrt_internalHitDepth*swrt_dir;

    samplePos = fract(samplePos)-0.5f;
    vec3 axDist = abs(samplePos);
    uint axis = (axDist.x<max(axDist.y,axDist.z))? (axDist.z>axDist.y? 2u : 1u) : 0u;
    uint sampleAxis = (axis<<1)+uint(samplePos[axis]>0);

    if(swrt_internalHitDepth>nudge){
        uint shape = blockShape(swrt_voxel);
        if((shape>>4)==3u){
            sampleAxis = (shape&0xfu)^1u;
        }else{
            sampleAxis=3u;
        }
        axis = sampleAxis>>1;
    }

    vec4 texData = getTexVoxData(areaPos,sampleAxis,unitShift);

    if(axis>0)
        samplePos = axis==1u? samplePos.yzx : samplePos.zxy;

    if(texData.xy==vec2(0))
        return vec4(0);
    texData.zw-=0.25;

    if(texData.w>0.25){
        texData.w-=0.5;
        samplePos.yz=samplePos.zy;
    }

    texData.xy+=texData.zw*clamp(samplePos.yz,-0.49,0.49);
    return texture(blockAtlas,texData.xy);
}
#endif



bool rayHitsShapedBlock(vec3 samplePos, vec3 dir, uint shape){
    samplePos=fract(samplePos);
    vec3 postPos = samplePos+dir*swrt_nextDepth;
    uint shapeCat = shape>>4;

    uint slabCheckAxis=2u;
    float slabCheckDepth = 0f;

    if(shapeCat<=2u){
        slabCheckDepth=8f;
        slabCheckAxis|=shapeCat;
    }else if (shapeCat==3u){
        slabCheckAxis=shape&0xfu;
        slabCheckDepth=3f;
    }else if (shapeCat==4u){
        slabCheckDepth=shape&0xfu;
    }

    vec2 axisCoords = vec2(samplePos[slabCheckAxis>>1],postPos[slabCheckAxis>>1]);
    if(bool(slabCheckAxis&1u))
        axisCoords=1f-axisCoords;
    slabCheckDepth*=0.0625;
    if(min(axisCoords.x,axisCoords.y)<slabCheckDepth){
        if(axisCoords.x>slabCheckDepth){
            swrt_internalHitDepth = swrt_nextDepth* abs(slabCheckDepth-axisCoords.x)/abs(axisCoords.y-axisCoords.x);
        }
        return true;
    }

    if(shapeCat<=2u){
        vec3 halfwayChange = samplePos + dir*(minDepthTillChange(samplePos*2,dir)*0.5+nudge);
        uint corners = 1u << (uint(halfwayChange.x<0.5)+2*uint(halfwayChange.z<0.5));
        corners |= 1u << (uint(samplePos.x<0.5)+2*uint(samplePos.z<0.5));
        corners |= 1u << (uint(postPos.x<0.5)+2*uint(postPos.z<0.5));

        if(bool(shape&corners))
            return true;
    }

    return false;
}



bool anyHit(){
    #if SWRT_TRANSLUCENCY>0
    if(blockIsTranslucent(swrt_voxel))
        swrt_translucency = (swrt_translucency<<6) | blockLightID(swrt_voxel);
    #endif

    if(swrt_distToFinal==1 && swrt_voxel==swrt_finalVoxel)
        return false;

    if(bool(swrt_voxel&WORLDVOX_OPAQUE))
        return true;

    bool bonusCheckDone = false;
    #ifdef SWRT_SHAPED_BLOCKS
    swrt_internalHitDepth = 0f;
    //TODO better coherence on this, do it in batches
    uint shape = blockShape(swrt_voxel);
    if(shape>=16u){
        bonusCheckDone=true;
        if(!rayHitsShapedBlock(swrt_hitpos.xyz,swrt_dir,shape))
            return false;
    }
    #endif

    #ifdef SWRT_CUTOUT_TRACE
    if(blockIsCutout(swrt_voxel)){
        bonusCheckDone=true;
        vec4 tex = texturedHit(swrt_hitpos.xyz,swrt_areaPos);
        if(tex.a<0.875)
            return false;
    }
    #endif

    return bonusCheckDone;
}



float traceRay(vec3 worldPos, vec3 worldDirToLight, uint maxSteps){
    worldPos+=(VOXELIZATION_SIZE>>1)-unitShift;

    ivec3 finalBlock = ivec3(floor(worldPos+worldDirToLight));
    swrt_finalVoxel = getBaseVoxData(finalBlock,unitShift);

    float maxTraceDepth = length(worldDirToLight);
    swrt_dir=normalize(worldDirToLight);

    swrt_hitpos.a = nudge;
    for(int i=0;i<maxSteps && swrt_hitpos.a<maxTraceDepth;i++){
        swrt_hitpos.a+=swrt_nextDepth;

        swrt_hitpos.xyz = worldPos+swrt_hitpos.a*swrt_dir;
        swrt_areaPos = ivec3(floor(swrt_hitpos.xyz));
        swrt_voxel = getBaseVoxData(swrt_areaPos,unitShift);
        swrt_nextDepth = minDepthTillChange(swrt_hitpos.xyz,swrt_dir)+nudge;

        swrt_distToFinal = abs(swrt_areaPos.x-finalBlock.x)+abs(swrt_areaPos.y-finalBlock.y)+abs(swrt_areaPos.z-finalBlock.z);

        if(swrt_distToFinal==0)
            return -1;

        if(anyHit())
            return swrt_hitpos.a;
    }

    return -1;
}

vec3 unpackSwrtTranslucency(){
    vec3 transColor = vec3(1f);
    for(int i=0;(i<SWRT_TRANSLUCENCY)&&bool(swrt_translucency);i++){
        transColor*= getLightIDColor(swrt_translucency&0x3fu);
        swrt_translucency>>=6;
    }
    return transColor;
}