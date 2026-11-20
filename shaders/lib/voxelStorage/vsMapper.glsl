#define WRITES_BASE_VOX
#include "/lib/voxelStorage/vsAccess.glsl"
#include "/lib/voxelStorage/blockPacking.glsl"

void writeVoxelMap(vec3 worldPos, int rawBlockID, uint emission){
    uint packedData = packVoxelForStorage(rawBlockID,emission);

    ivec3 shift = getUnitShift();
    ivec3 areaPos = ivec3(floor(worldPos))+(VOXELIZATION_SIZE>>1)-shift;

    //TODO dont update whole thing each frame
    setBaseVoxData(packedData, areaPos,shift);
}

#include "/lib/util/uniforms/frameCounter"

#ifdef TEXTURED_VOXELIZATION
void writeVoxelMapTextured(vec3 worldPos, int rawBlockID, uint emission){
    uint packedData = packVoxelForStorage(rawBlockID,emission);

    ivec3 shift = getUnitShift();
    ivec3 areaPos = ivec3(floor(worldPos))+(VOXELIZATION_SIZE>>1)-shift;

    uint axis = 0u;
    if(abs(gl_Normal.x)<(abs(gl_Normal.y)+abs(gl_Normal.z)))
        axis=(abs(gl_Normal.y)>abs(gl_Normal.z))?1u:2u;


    vec4 texData = vec4(mc_midTexCoord,abs(mc_midTexCoord-(gl_TextureMatrix[0] * gl_MultiTexCoord0).xy));

    vec3 tan = normalize(at_tangent.xyz);
    uvec2 nextAxes = uvec2(axis+1,axis+2)%3;

    bool flipxy = abs(tan[nextAxes.y])>0.5;
    if(flipxy)
        nextAxes.xy=nextAxes.yx;

    vec3 bitan = normalize(cross(at_tangent.xyz,gl_Normal)*at_tangent.w);
    texData.zw=(texData.zw*vec2(tan[nextAxes.x],bitan[nextAxes.y]))*2f+0.25;
    if(flipxy)
        texData.w+=0.5;

    axis = (axis<<1)+uint(gl_Normal[axis]>0);

    setTexturedBaseVoxData(packedData, texData, areaPos, axis, shift);
}
#endif