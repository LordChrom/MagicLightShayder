uniform float aspectRatio;
uniform bool hideGUI;
uniform mat4 gbufferModelView;

const vec2 bonusHudSpot = vec2(0.03,0.03);
const float bonusHudScale = 0.02;
const float bonusHudBirghtness = 0.25;


void renderAxisGizmo(inout vec3 color, vec2 texcoord){
    if(hideGUI)
        return;
    texcoord.x*=aspectRatio;
    texcoord/=bonusHudScale;
    texcoord-=bonusHudSpot/bonusHudScale;

    float maxTxAbs = max(abs(texcoord.x),abs(texcoord.y));
    if(maxTxAbs>1)
        return;


    float len = length(texcoord);
    if(len>1) return;
    if(0.95<len) color+=5.0/255;

    float angle = atan(texcoord.y,texcoord.x);
    texcoord=normalize(texcoord);
    vec3 axisAngles=vec3(
        atan(gbufferModelView[0][1],gbufferModelView[0][0]),
        PI/2,
        atan(gbufferModelView[2][1],gbufferModelView[2][0])
    );
    axisAngles=abs(axisAngles-angle);
    float wideness = atan(0.07/len);

    vec3 axisLen = abs(vec3(
        gbufferModelView[0].z,
        gbufferModelView[1].z,
        gbufferModelView[2].z
    ));
    axisLen=pow(1-axisLen,vec3(0.25)); //probably not correct but its pretty close & i care about perf more than the remaining difference

    if((axisAngles.x<=wideness || axisAngles.x>=2*PI-wideness) && (len<=axisLen.x))
        color.r+=bonusHudBirghtness;
    if((axisAngles.y<=wideness || axisAngles.y>=2*PI-wideness) && (len<=axisLen.y))
        color.g+=bonusHudBirghtness;
    if((axisAngles.z<=wideness || axisAngles.z>=2*PI-wideness) && (len<=axisLen.z))
        color.b+=bonusHudBirghtness;
}