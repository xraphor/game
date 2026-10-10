shader_type spatial;
uniform vec4 complexion : source_color = vec4(0.45,0.28,0.17,1.0);
float hash(vec2 p) {return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment() {
    float pores = hash(floor(UV*1700.0));
    float soft = sin(UV.x*160.0)*sin(UV.y*110.0);
    ALBEDO=complexion.rgb*(0.94+pores*0.06+soft*0.025);
    ROUGHNESS=0.43+pores*0.14;
    SPECULAR=0.38;
    NORMAL_MAP=normalize(vec3((pores-0.5)*0.15,(hash(floor(UV*1700.0)+vec2(1.0))-0.5)*0.15,1.0))*0.5+0.5;
}
