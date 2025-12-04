Shader "shader lab/week 13/ether - glsl to hlsl" {
    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #define t _Time.y
            
            struct MeshData {
                float4 vertex : POSITION;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);
                return o;
            }


            float2x2 m(float a) {
                float c = cos(a);
                float s = sin(a);
                return float2x2(c,-s,s,c);
            }
            
            float map(float3 p){
                p.xz = mul(m(t*0.4), p.xz);
                p.xy = mul(m(t*0.3), p.xy);
                
                float3 q = p* 2. + t;
                return length(p+(sin(t*0.7)))*log(length(p)+1.) + sin(q.x+sin(q.z+sin(q.y)))*0.5 - 1.;
            }
            
            float4 frag (Interpolators i) : SV_Target {
                float2 uv = i.vertex.xy/_ScreenParams.y - 0.5;
                float3 cl = 0;
                float d = 2.5;
                for(int i=0; i<=5; i++)	{
                    float3 p = float3(0,0,5.) + normalize(float3(uv, -1.))*d;
                     float rz = map(p);
                     float f =  clamp((rz - map(p+.1))*0.5, -.1, 1. );
                     float3 l = float3(0.1,0.3,.4) + float3(5., 2.5, 3.)*f;
                     cl = cl*l + smoothstep(2.5, .0, rz)*.7*l;
                     d += min(rz, 1.);
                }
                return float4(cl, 1.);
            }
            ENDHLSL
        }
    }
}

// Ether by nimitz 2014 (twitter: @stormoid)
// https://www.shadertoy.com/view/MsjSW3
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License
// Contact the author for other licensing options

// #define t iTime
// mat2 m(float a){float c=cos(a), s=sin(a);return mat2(c,-s,s,c);}
// float map(vec3 p){
//     p.xz*= m(t*0.4);p.xy*= m(t*0.3);
//     vec3 q = p*2.+t;
//     return length(p+vec3(sin(t*0.7)))*log(length(p)+1.) + sin(q.x+sin(q.z+sin(q.y)))*0.5 - 1.;
// }

// void mainImage( out vec4 fragColor, in vec2 fragCoord ){	
//     vec2 p = fragCoord.xy/iResolution.y - vec2(.9,.5);
//     vec3 cl = vec3(0.);
//     float d = 2.5;
//     for(int i=0; i<=5; i++)	{
//         vec3 p = vec3(0,0,5.) + normalize(vec3(p, -1.))*d;
//         float rz = map(p);
//         float f =  clamp((rz - map(p+.1))*0.5, -.1, 1. );
//         vec3 l = vec3(0.1,0.3,.4) + vec3(5., 2.5, 3.)*f;
//         cl = cl*l + smoothstep(2.5, .0, rz)*.7*l;
//         d += min(rz, 1.);
//     }
//     fragColor = vec4(cl, 1.);
// }