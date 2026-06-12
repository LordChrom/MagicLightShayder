#ifndef VOXY_PATCH
#version 430 compatibility
#endif

#include "/lib/settings.glsl"

#ifdef VOXY_PATCH
    #if MATERIALS_TYPE>=1
        #define NEEDS_MATERIAL_ID
        #define HARDCODED_MATERIAL
        #define MATERIALS_TYPE 0
        #include "/lib/util/materialId.glsl"
    #endif

    #if MATERIALS_TYPE < 0
        #undef WRITE_MATERIALS
    #endif
    #undef FORWARD_TRANSLUCENTS
    #undef POM
#else

#if (DEBUG_SPECIAL_VIEW == 104)
#undef TRANSLUCENT
#endif

#if MATERIALS_TYPE < 0
    #undef WRITE_MATERIALS
#endif

#if (defined WRITE_MATERIALS) && (MATERIALS_TYPE == 0)
    #define NEEDS_MATERIAL_ID
    #define HARDCODED_MATERIAL
    flat in uvec4 hardcodedMaterialInfo;
    #if !(HARDCODED_EMISSIVE_SELECTIVITY==-1)
        #define NEEDS_MATERIAL_ID
    #endif
#endif

#ifdef TEXTURED
in vec2 texcoord;
uniform sampler2D gtexture;
    #if MATERIALS_TYPE ==1
uniform sampler2D specular;
uniform sampler2D normals;
flat in mat3 normalRotator;
    #endif
#endif

#ifdef LIT
in vec2 lmcoord;
uniform sampler2D lightmap;
#endif

#ifdef VERTEX_NORMALS
in vec3 normal;
#endif

#ifdef ALPHATEST
uniform float alphaTestRef = 0.1;
#endif

#ifdef ENTITY
uniform vec4 entityColor;
#endif

#ifdef BONUS_STUFF
void doBonusStuff();
#endif

#ifdef BASIC
in flat vec4 glcolor;
#else
in vec4 glcolor;
#endif

#ifdef NEEDS_MATERIAL_ID
flat in int materialID;
#include "/lib/util/materialId.glsl"
#endif

#if defined FORWARD_TRANSLUCENTS && defined TRANSLUCENT && defined LIT
    in vec3 worldPos;
    uniform vec3 cameraPosition;
    #include "/lib/voxel/voxelSampler.glsl"
    #include "/lib/util/dither.glsl"
#else
    #undef FORWARD_TRANSLUCENTS
#endif

#if defined MAYBE_END_GATEWAY && defined GATEWAYS_IN_GBUFFER
    uniform float viewWidth, viewHeight;
    #include "/lib/renderComponents/endGateway.glsl"
#elif defined FORWARD_TRANSLUCENTS
    uniform float viewWidth, viewHeight;
#endif

#ifdef FORWARD_TRANSLUCENTS
    /* RENDERTARGETS: 1 */
#elif defined TRANSLUCENT
    #ifdef WRITE_MATERIALS
    /* RENDERTARGETS: 1,2,5,4 */
    #else
    /* RENDERTARGETS: 1,2,5 */
    #endif
#else
    #ifdef WRITE_MATERIALS
    /* RENDERTARGETS: 0,2,5,3 */
    #else
    /* RENDERTARGETS: 0,2,5 */
    #endif
#endif

#endif


#ifdef HAND
    #define NORMAL_A 0.5
#elif defined TRANSLUCENT
    #define NORMAL_A 1
#else
    #define NORMAL_A 0
#endif

#ifndef POM_ELLIGIBLE
    #undef POM
#endif

#ifdef POM
    in vec2 differential;
    flat in ivec2 baseTexpos;
    flat in ivec2 texsize;
    uniform ivec2 atlasSize;
    float rayDepth=0;
    #include "/lib/renderComponents/pom.glsl"
    #include "/lib/util/conversions.glsl"
#endif

layout(location = 0) out vec4 color;
#ifdef FORWARD_TRANSLUCENTS
vec4 normalOut;
vec4 vanillaLighting;
uvec4 materialInfo;
#else
layout(location = 1) out vec4 normalOut;

#ifdef VANILLA_FALLBACK
layout(location = 2) out vec4 vanillaLighting;
#endif
#ifdef WRITE_MATERIALS
layout(location = 3) out uvec4 materialInfo;
#endif
#endif

/*
const vec4 colortex1ClearColor = vec4(0.0,0.0,0.0,0.0);
*/

#ifdef VOXY_PATCH
void handleFragment(vec4 glcolor,vec3 normal, vec2 lmcoord, vec4 voxySampledColor, int materialID)

#if 0
;//for my IDE :/
#endif

#else
void main()
#endif
{
#ifdef TEXTURED
    #ifdef POM
        vec2 newTexcoord=doPom(texcoord);
        float linearDepth = depthToLinear(gl_FragCoord.z);
        #ifdef POM_WRITE_DEPTH
        rayDepth = length(vec3(differential/texsize,1))*rayDepth;
        linearDepth+=rayDepth;
        gl_FragDepth=depthToBuf(linearDepth);
        #endif
    #else
//        gl_FragDepth=gl_FragCoord.z;
        #define newTexcoord texcoord
    #endif
#endif

#ifdef LIT
    #ifdef VOXY_PATCH
    vec4 lighting = voxyLighting(lmcoord);
    #else
    vec4 lighting = texture(lightmap, lmcoord);
    #endif
#elif defined BASIC
    bool isLeash = length(glcolor.xyz-vec3(0.425,0.34,0.25))<0.5;
    vec4 lighting = isLeash?vec4(0.9,0.9,0.9,1):vec4(1.0);
#else
    vec4 lighting = vec4(1.0);
#endif

#ifdef MAYBE_END_GATEWAY
    bool isEndGateway = materialID==55498;
    vec4 sampledColor;

    if(isEndGateway){
        lighting=vec4(1.0);
        sampledColor = vec4(doEndGateway(gl_FragCoord.xy/vec2(viewWidth,viewHeight)),1);
    }else{
        sampledColor = glcolor*texture(gtexture, newTexcoord);
    }

#elif defined VOXY_PATCH
    vec4 sampledColor = voxySampledColor*glcolor;
#elif defined TEXTURED
    vec4 sampledColor = glcolor * texture(gtexture, newTexcoord);
#else
    vec4 sampledColor = glcolor * lighting;
#endif

#ifdef ENTITY
    sampledColor.rgb = mix(sampledColor.rgb, entityColor.rgb, entityColor.a);
#endif

#ifdef ALPHATEST
    if (sampledColor.a < alphaTestRef) {
        discard;
    }
#endif

#ifdef VERTEX_NORMALS
    #if (defined TEXTURED) && (MATERIALS_TYPE == 1)
    vec4 pbrNormalSample = texture(normals,newTexcoord);

    pbrNormalSample.xy = (pbrNormalSample.xy-0.5)*(2*PBR_NORMALS_STRENGTH);
    pbrNormalSample/=max(1,length(pbrNormalSample.xy));

    vec3 texNormal = vec3(pbrNormalSample.xy,sqrt(1.0 - dot(pbrNormalSample.xy, pbrNormalSample.xy)));

    #if (defined POM_NORMALS) && (defined POM)
    if(length(pomEdgeDif)>1)
        pomEdgeDif=ivec2(0);

    pomEdgeDif=ivec2(sign(differential))*-abs(pomEdgeDif);
    vec3 pomEdgeNormal = vec3(
        pomEdgeDif,0
    );

    pomEdgeNormal*=min(1.5,3/linearDepth);
    texNormal = normalize(texNormal+pomEdgeNormal);
    #endif

    texNormal = normalize(normalRotator*texNormal);

    #if (defined POM) && DEBUG_SPECIAL_VIEW==104
        bool checker = bool((int(floor(texcoord.x*atlasSize.x))+int(floor(texcoord.y*atlasSize.y)))&1);
        sampledColor.xyz=vec3(abs(max(differential.xy,checker?0:-1)),0);
    //        sampledColor.xyz=vec3(pbrNormalSample.a);
    #endif

    normalOut = vec4((texNormal+1)*0.5,NORMAL_A);
    #else
    normalOut = vec4((normal+1)*0.5,NORMAL_A);
    #endif

    #ifdef TRANSLUCENT
    if(sampledColor.a<=translucentPrecedenceCutoff)
        normalOut.a=0;
    #endif
#endif


//TODO the translucent part is for viewing fully lit stuff thru transparents, prolly a better solution tho
#if defined VANILLA_FALLBACK && ((!defined TRANSLUCENT) || (defined FAKE_TRANSLUCENT))
    vanillaLighting=lighting;
#endif

    color = sampledColor;

#ifdef WRITE_MATERIALS
    #if MATERIALS_TYPE == 0 //hardcoded
        #ifdef VOXY_PATCH
    materialInfo = getHardcodedMaterial(materialID);
        #else
    materialInfo = hardcodedMaterialInfo;
        #endif

        #if !(HARDCODED_EMISSIVE_SELECTIVITY==-1)
    if(materialInfo.a!=255){
        vec3 lightColor = getMaterialColor(materialID);
        float brightness = dot(color.rgb/glcolor.rgb,normalize(lightColor));
        brightness*=brightness;
        brightness = brightness*HARDCODED_EMISSIVE_SELECTIVITY + (1-HARDCODED_EMISSIVE_SELECTIVITY);
        materialInfo.a=uint(clamp(brightness,0,1)*materialInfo.a);
    }
        #endif

    #elif MATERIALS_TYPE == 1 //PBR pack
    materialInfo = uvec4(round(clamp(texture(specular,newTexcoord)*255.0,0,255)));
    #endif

    #ifdef TRANSLUCENT

    if(sampledColor.a<translucentPrecedenceCutoff)
        materialInfo.a=255;
    #endif
#endif


    #ifdef BONUS_STUFF
    doBonusStuff();
    #endif

    #ifdef FORWARD_TRANSLUCENTS
    float ditherValue = dither(ivec2(floor(vec2(texcoord)*vec2(viewWidth,viewHeight)-0.01)));
    float emissive = (materialInfo.a!=255)?materialInfo.a/254.0:0;
    float subsurface = clamp(float(materialInfo.b-64)/190.0, 0.0,1.0);
    #ifdef NEEDS_MATERIAL_ID
    if(materialID==24709)
        emissive=1;
    #endif
    #ifdef MAYBE_END_GATEWAY
    if(!isEndGateway)
    #endif
    {
        if(emissive>0)
            color.rgb*=(EMISSIVE_BRIGHTNESS*emissive);
        else
            color.rgb*=voxelSample(worldPos, normalize(normalOut.xyz*2-1), subsurface, ditherValue)+(EMISSIVE_BRIGHTNESS*emissive);
    }
    #endif
}