uniform mat4 gbufferModelView, gbufferProjection;
uniform mat4 gbufferModelViewInverse, gbufferProjectionInverse;
uniform float near,far;
#include "/lib/util/conversions.glsl"


in vec2 texcoord;
in vec3 worldDirNormalizeMe;

uniform sampler2D depthtex2;
uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform usampler2D colortex3;


/* RENDERTARGETS: 0 */
layout(location = 0) out vec3 outputColor;

vec3 reflect(vec3 dir, vec3 norm){
    return normalize(dir-norm*(2*dot(norm,dir)));
}

vec3 worldPosToView(vec3 worldPos){
    vec4 pos = vec4(mat3(gbufferModelView)*worldPos,1);
    pos=gbufferProjection*pos;
    return (pos.xyz*(0.5/pos.w))+0.5;
}

vec3 viewPosToWorld(vec3 view){
    vec4 pos = vec4(view*2-1,1);
    pos=gbufferProjectionInverse*pos;
    pos/=pos.w;
    return mat3(gbufferModelViewInverse)*pos.xyz;
}

//TODO gotta be a better way to do this
vec3 worldDirToView(vec3 worldNormal, vec3 viewPos){
    float dif = 0.01;
    vec3 worldPos = viewPosToWorld(viewPos);
    vec3 viewPosDif = worldPosToView(worldPos+dif*worldNormal)-viewPos;
    return normalize(viewPosDif);
}

vec3 debugChecker(vec3 value){
    ivec2 awa = ivec2(gl_FragCoord.xy)>>3;
    vec3 checker = sign(value);
    if(bool(1&(awa.x^awa.y)))
        checker=vec3(1);
    return vec3(abs(value)*vec3(checker.x>=0,checker.y>=0,checker.z>=0));
}


vec3 doMarch(vec3 initialPos, vec2 differential){
    const int steps=1000;
    float stepSize =0.004/length(differential);
    for(int i=1;i<=steps;i++){
        float depthDist = stepSize*i;
        vec3 newPos = initialPos+vec3(depthDist*differential,depthDist);
        if(newPos.x<0||newPos.y<0||newPos.x>1||newPos.y>1)
            return vec3(-1);
        float texDepth = texture(depthtex2,newPos.xy).x;
        if(texDepth<=newPos.z)
            return newPos;
    }

    return vec3(-1);
}

void main() {
    outputColor = texelFetch(colortex0,ivec2(gl_FragCoord.xy),0).rgb;
    vec3 normal = normalize(texelFetch(colortex2,ivec2(gl_FragCoord.xy),0).rgb*2-1);
    uint reflectance = texelFetch(colortex3,ivec2(gl_FragCoord.xy),0).g;

//    return;
    //TODO remove testing threshold
    if(reflectance<128)
        return;



    float depth = texelFetch(depthtex2,ivec2(gl_FragCoord.xy),0).x;
//    depth=depthToLinear(depth);
    vec3 worldDir = normalize(worldDirNormalizeMe);
    worldDir=reflect(worldDir,normal);
    vec3 viewDir;
//    viewDir= mat3(gbufferModelView)*worldDir;
    viewDir=worldDirToView(worldDir,vec3(texcoord,depth));

    if(viewDir.z<0)
        return;

    vec3 marchedPos = doMarch(vec3(texcoord,depth),viewDir.xy/viewDir.z);
    if(marchedPos==vec3(-1))
        return;

//    outputColor=vec3(marchedtc,0);
    vec3 reflectionColor = texture(colortex0,marchedPos.xy).rgb;
    if(reflectance<=229)
        reflectionColor*=(reflectance/255.0);
    else{
        reflectionColor*=outputColor;
    }
    outputColor+=reflectionColor;

//    outputColor=debugChecker(vec3(viewDir.xy/viewDir.z,0));
//    viewDir.xyz=vec3(0,0,viewDir.z*0.4);
//    outputColor=debugChecker(viewDir.xyz);


}