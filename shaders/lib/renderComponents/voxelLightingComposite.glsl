#include "/lib/voxel/voxelSampler.glsl"

uniform sampler2D colortex4;
//uniform sampler2D depthtex0;
uniform sampler2D depthtex2;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;


///* RENDERTARGETS: 6 */
//layout(location = 0) out vec4 lighting;

vec4 voxelLighting;

void doVoxelLighting(vec2 sampleTexCoord, ivec2 texpos) {

    //	float depth = texelFetch(depthtex0,texpos,0).x;
    float solidDepth = texelFetch(depthtex2,texpos,0).x;
    vec4 normalAndMore = texelFetch(colortex4,texpos,0);

    vec3 ndcPos = vec3(vec3(sampleTexCoord,solidDepth)*2-1);

    vec3 normal = normalize(normalAndMore.xyz*2-1);

    if(normalAndMore.a>0.5) //currently, normal.a only stores if it is or isnt the hand
    ndcPos.z/=MC_HAND_DEPTH;

    vec4 viewPos = gbufferProjectionInverse*vec4(ndcPos,1);
    viewPos/=viewPos.w;

    vec3 worldPos = (gbufferModelViewInverse*viewPos).xyz+cameraPosition;

    bool voxelLit = isVoxelInBounds(worldPos+normal);
    if(voxelLit)
        voxelLighting = vec4(voxelSample(worldPos,normal),1);
    else
        voxelLighting = vec4(0);
}