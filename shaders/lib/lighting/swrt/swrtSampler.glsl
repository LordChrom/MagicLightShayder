#define READS_LIGHT_LIST
#define READS_BASE_VOX
#include "/lib/voxelStorage/volumeShifting.glsl"
#include "/lib/voxelStorage/blockPacking.glsl"
#include "/lib/voxelStorage/vsAccess.glsl"
#include "/lib/lighting/swrt/lightListAccess.glsl"
#include "/lib/util/uniforms/frameCounter"



ivec3 worldPosToSWRT(vec3 pos){
    ivec3 ret = ivec3(floor(pos))-ivec3(floor(globalOrigin));
    ret+=SWRT_SIZE>>1;
    return ret;
}
//
bool traceRayToOneLight(vec3 worldPos, vec3 worldDirToLight, ivec3 unitShift){
    ivec3 initialBlock = ivec3(floor(worldPos))+(VOXELIZATION_SIZE>>1)-unitShift;
    ivec3 finalBlock = ivec3(floor(worldPos+worldDirToLight))+(VOXELIZATION_SIZE>>1)-unitShift;

    float maxTraceDepth = length(worldDirToLight);
    worldDirToLight=normalize(worldDirToLight);

    float tiny = 0.001;



    #define RT_STEPS 10
    float depth = 0;
    for(int i=0;i<RT_STEPS && depth<maxTraceDepth;i++){
        depth+=tiny;
        vec3 samplePosition = worldPos+depth*worldDirToLight;
        ivec3 areaPos = ivec3(floor(samplePosition))+(VOXELIZATION_SIZE>>1)-unitShift;
        if(areaPos==finalBlock)
            return false;

        uint voxel = getBaseVoxData(areaPos,unitShift);

        if(bool(voxel)){
            if(bool(voxel&WORLDVOX_OPAQUE))
                return true;
        }

        vec3 depthTillPxEdge = (1-fract(samplePosition*sign(worldDirToLight)))/abs(worldDirToLight);
        depth+=min(min(depthTillPxEdge.x,depthTillPxEdge.y),depthTillPxEdge.z);
    }

    return false;
}

vec4 swrtSample(vec3 worldPos, vec3 normal, float subsurface, float ditherValue){
    worldPos+=0.01*normal;
    vec4 color = vec4(0);
    ivec3 unitShift = getUnitShift();
    ivec3 swrtPos = worldPosToSWRT(worldPos);

    if(swrtPos.x<0||swrtPos.y<0||swrtPos.z<0||
        swrtPos.x>=SWRT_SIZE||swrtPos.y>=SWRT_SIZE||swrtPos.z>=SWRT_SIZE
    ){
        return vec4(0);
    }

    uvec4 list = getLightList(swrtPos,unitShift);
    ivec3 areaPos = swrtPos+offsetToVox;

//    uint numLights = countLights(list);
//    uint i = (uint(ditherValue*numLights)+frameCounter)%numLights;

    for(uint i=0;i<8;i++)
    {
        uint light = getNthLight(list,i);
        if(!bool(light&LIGHT_VALID_BIT))
            return color;
        ivec3 lightPosRel = uncheckedUnpackListedLight(light);
        vec3 displacementToLight = lightPosRel-fract(worldPos)+0.5;
        float distanceToLight = length(displacementToLight);
        ivec3 lightPos = areaPos+lightPosRel;

        bool hitObstruction = traceRayToOneLight(worldPos,displacementToLight,unitShift);
        if(!hitObstruction){
            uint voxel = getBaseVoxData(lightPos,unitShift);
            color.rgb+=worldVoxColor(voxel)/(distanceToLight*distanceToLight);
        }
    }

//    color*=numLights;

    return color;
}