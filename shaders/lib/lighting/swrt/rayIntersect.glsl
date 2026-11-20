const uint signBit = 0x80000000u;
//float depthTillChange(float value, float differential){
//    return (1-fract(value*sign(differential)))/abs(differential);
//}

float minDepthTillChange(vec2 value, vec2 differential){
    value = uintBitsToFloat(floatBitsToUint(value)^(floatBitsToUint(differential)&signBit));
    value = fract(-value)/abs(differential);
    return min(value.x,value.y);
}

float minDepthTillChange(vec3 value, vec3 differential){
    value = uintBitsToFloat(floatBitsToUint(value)^(floatBitsToUint(differential)&signBit));
    value = fract(-value)/abs(differential);
    return min(min(value.x,value.y),value.z);
}
const float nudge = 0.0001;


vec4 swrt_hitpos; //a is depth
vec4 swrt_dir;    //a is depth increment for next block
uint swrt_translucency = 0u;
uint swrt_voxel = 0u;
float swrt_internalHitDepth = 0f;



#ifdef SWRT_TEXTURED
uniform sampler2D blockAtlas;
vec4 swrtTextureSample(){
    vec3 samplePos=swrt_hitpos.xyz+ swrt_internalHitDepth*swrt_dir.xyz;

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

    vec4 texData = getTexVoxData(ivec3(floor(swrt_hitpos.xyz)),sampleAxis,unitShift);

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



bool rayHitsShapedBlock(){
    uint shape = blockShape(swrt_voxel);

    uint slabCheckAxis=2u;
    float slabCheckDepth = 0f;

    if(shape<=0x2fu){
        slabCheckDepth=8f;
        slabCheckAxis|=shape>>4;
    }else if (shape<=0x3fu){
        slabCheckAxis=shape&0xfu;
        slabCheckDepth=3f;
    }else if (shape<=0x4fu){
        slabCheckDepth=shape&0xfu;
    }

    vec3 samplePos=fract(swrt_hitpos.xyz);
    vec3 postPos = samplePos+swrt_dir.xyz*swrt_dir.a;

    if(slabCheckDepth>0){
        vec2 axisCoords = vec2(samplePos[slabCheckAxis>>1],postPos[slabCheckAxis>>1]);
        if(bool(slabCheckAxis&1u))
            axisCoords=1f-axisCoords;
        slabCheckDepth*=0.0625;
        if(min(axisCoords.x,axisCoords.y)<slabCheckDepth){
            #ifdef SWRT_CUTOUT_TRACE
            if(axisCoords.x>slabCheckDepth){
                swrt_internalHitDepth = swrt_dir.a* abs(slabCheckDepth-axisCoords.x)/abs(axisCoords.y-axisCoords.x);
            }
            #endif
            return true;
        }
    }

    if(shape<=0x2fu){
        vec2 halfwayChange = samplePos.xz + swrt_dir.xz*(minDepthTillChange(samplePos.xz*2,swrt_dir.xz)*0.5+nudge);
        uint corners = 1u << (uint(halfwayChange.x<0.5)+2*uint(halfwayChange.y<0.5));
        corners |= 1u << (uint(samplePos.x<0.5)+2*uint(samplePos.z<0.5));
        corners |= 1u << (uint(postPos.x<0.5)+2*uint(postPos.z<0.5));

        if(bool(shape&corners))
            return true;
    }

    if((shape>>4)==5u){
        float poleSize = (shape&0xfu);
        poleSize*=0.0625;

        float m = (postPos.z-samplePos.z)/(postPos.x-samplePos.x);

        //TODO this feels very inefficient but it works for now
        vec2 poses = vec2(0.5-poleSize,0.5+poleSize)*m+(samplePos.z-m*samplePos.x);
        poses = clamp(poses,min(postPos.z,samplePos.z),max(postPos.z,samplePos.z));
        poses-=0.5;

        if(poses.x*poses.y<0 || abs(poses.x)<poleSize|| abs(poses.y)<poleSize){
            poses = vec2(0.5-poleSize,0.5+poleSize)/m+(samplePos.x-samplePos.z/m);
            poses = clamp(poses,min(postPos.x,samplePos.x),max(postPos.x,samplePos.x));
            poses-=0.5;

            if(poses.x*poses.y<0 || abs(poses.x)<poleSize|| abs(poses.y)<poleSize)
                return true;
        }
    }

    return false;
}



bool anyHit(){
    #if SWRT_TRANSLUCENCY>0
    if(blockIsTranslucent(swrt_voxel))
        swrt_translucency = (swrt_translucency<<6) | blockLightID(swrt_voxel);
    #endif

    if(bool(swrt_voxel&WORLDVOX_OPAQUE)
        #ifdef SWRT_CUTOUT_TRACE
        && !blockIsCutout(swrt_voxel)
        #endif
    )
        return true;

    bool bonusCheckDone = false;
    #ifdef SWRT_SHAPED_BLOCKS
    swrt_internalHitDepth = 0f;
    //TODO better coherence on this, do it in batches
    if(blockShape(swrt_voxel)>=16u){
        bonusCheckDone=true;
        if(!rayHitsShapedBlock())
            return false;
    }
    #endif

    #ifdef SWRT_CUTOUT_TRACE
    if(blockIsCutout(swrt_voxel)){
        bonusCheckDone=true;
        vec4 tex = swrtTextureSample();
        if(tex.a<0.875)
            return false;
    }
    #endif

    return bonusCheckDone;
}



float traceRay(vec3 worldPos, vec3 worldDirToLight){
    swrt_dir.xyz=normalize(worldDirToLight);
    worldPos+=(VOXELIZATION_SIZE>>1)-unitShift;

    float maxTraceDepth = length(worldDirToLight)-minDepthTillChange(vec3(0.5),swrt_dir.xyz)-nudge;

    swrt_hitpos.a = 0f;
    for(int i=0;i<swrtMaxSteps && swrt_hitpos.a<maxTraceDepth;i++){
        swrt_hitpos.xyz = worldPos+swrt_hitpos.a*swrt_dir.xyz;
        swrt_voxel = getBaseVoxData(ivec3(floor(swrt_hitpos.xyz)),unitShift);
        swrt_dir.a = minDepthTillChange(swrt_hitpos.xyz,swrt_dir.xyz)+nudge;

        if(swrt_voxel>0){
            if(anyHit())
                return swrt_hitpos.a;
        }
        swrt_hitpos.a+=swrt_dir.a;
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