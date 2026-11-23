const uint signBit = 0x80000000u;

float minDepthTillChange(vec2 value, vec2 differential){
    value = uintBitsToFloat(floatBitsToUint(value)^(floatBitsToUint(differential)&signBit));
    value = fract(-value)/abs(differential);
    return min(value.x,value.y);
}

float minDepthTillChange(vec3 value, vec3 differential){
    value = uintBitsToFloat(floatBitsToUint(value)^(floatBitsToUint(differential)&signBit));
    value = (1f-fract(value))/abs(differential);
    return min(min(value.x,value.y),value.z);
}

const float nudge = 0.0001220703125; //2^-13, should immediate better i think


vec4 swrt_hitpos = vec4(0); //a is depth
vec4 swrt_dir = vec4(0);    //a is depth increment for next block
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
    axis = (axis<<1)+uint(samplePos[axis]>0);

    if(swrt_internalHitDepth>0f){
        uint shape = blockShape(swrt_voxel);
        axis = (shape>>4)==3u ? (shape&0xfu)^1u : 3u;
    }

    vec4 texData = imageLoad(texWorldVox,ivec3(swrt_hitpos.x,int(swrt_hitpos.y)*6+axis,swrt_hitpos.z));

    if(axis>1u)
        samplePos = (axis>3u)? samplePos.zxy : samplePos.yzx;

    if(texData.xy==vec2(0))
        return vec4(0);
    texData.zw-=0.25;

    if(texData.w>0.25){
        texData.w-=0.5;
        samplePos.yz=samplePos.zy;
    }

    samplePos.yz=clamp(samplePos.yz,-0.49,0.49);
    texData.xy+=texData.zw*samplePos.yz;
    return texelFetch(blockAtlas,ivec2(texData.xy*textureSize(blockAtlas,0)),0);
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
                swrt_internalHitDepth = swrt_dir.a* abs(slabCheckDepth-axisCoords.x)/abs(axisCoords.y-axisCoords.x)+nudge;
            }
            #endif
            return true;
        }
    }

    if(shape<=0x2fu){
        vec2 halfwayChange = samplePos.xz + swrt_dir.xz*(minDepthTillChange(samplePos.xyz,swrt_dir.xyz)*0.5+nudge);
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


//TODO better coherence on this, do it in batches
bool anyHit(){
    uint shape = blockShape(swrt_voxel);

#ifdef SWRT_SHAPED_BLOCKS
    if(shape<2){
        if(!blockIsCutout(swrt_voxel))
            return shape==1;
    }else if(!rayHitsShapedBlock())
        return false;

    #ifdef SWRT_CUTOUT_TRACE
    if(!blockIsCutout(swrt_voxel))
        return true;
    vec4 tex = swrtTextureSample();
    return tex.a>=0.875;
    #else
    return true;
    #endif
#else
    return shape>0;
#endif
}


uniform usampler3D baseWorldVoxSampler;

float traceRay(vec3 worldPos, vec3 worldDirToLight){
    swrt_dir.xyz=normalize(worldDirToLight);
    swrt_hitpos.xyz= worldPos + (VOXELIZATION_SIZE>>1);

    float maxTraceDepth = length(worldDirToLight)-minDepthTillChange(swrt_hitpos.xyz+worldDirToLight,-swrt_dir.xyz)-nudge;

    swrt_hitpos.a = 0f;
    int i=0;
    for(i=0;i<=swrtMaxSteps && swrt_hitpos.a<maxTraceDepth;i++){
        swrt_hitpos.xyz=fract(swrt_hitpos.xyz/VOXELIZATION_SIZE);
        swrt_voxel = texture(baseWorldVoxSampler,swrt_hitpos.xyz).x;
        swrt_hitpos.xyz*=VOXELIZATION_SIZE;

        swrt_dir.a=minDepthTillChange(swrt_hitpos.xyz,swrt_dir.xyz);

        swrt_internalHitDepth = 0f;

        if(swrt_voxel>0){
            if(anyHit()){
                if(!blockIsTranslucent(swrt_voxel))
                    break;
                #if SWRT_TRANSLUCENCY>0
                swrt_translucency = (swrt_translucency<<6) | blockLightID(swrt_voxel);
                #endif
            }
        }
        swrt_hitpos+=vec4(swrt_dir.a*swrt_dir.xyz,swrt_dir.a);

        //this biases to the next float in the direction of the sign of swrt_dir. DM me about if if you wanna know more
        swrt_hitpos.xyz=intBitsToFloat(floatBitsToInt(swrt_hitpos.xyz+1f)+((floatBitsToInt(swrt_dir.xyz)>>31)|1))-1f;
    }


    if(swrt_hitpos.a>=maxTraceDepth || i>=swrtMaxSteps)
        return -1;
    if(swrt_hitpos.a+swrt_dir.a>=maxTraceDepth && (blockShape(swrt_voxel)==1u) && bool(swrt_voxel&WORLDVOX_EMISSION_MASK))
        return -1;
    return swrt_hitpos.a;
}

vec3 unpackSwrtTranslucency(){
    vec3 transColor = vec3(1f);
    for(int i=0;(i<SWRT_TRANSLUCENCY)&&bool(swrt_translucency);i++){
        transColor*= getLightIDColor(swrt_translucency&0x3fu);
        swrt_translucency>>=6;
    }
    return transColor;
}