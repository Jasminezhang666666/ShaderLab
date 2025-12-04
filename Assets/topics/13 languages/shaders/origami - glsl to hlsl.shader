Shader "shader lab/week 13/origami - glsl to hlsl" {
    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #define R float2x2(cos(a/4.+float4(0,11,33,0)))
            
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
            
            float4 frag (Interpolators i) : SV_Target {
                //Initialize hue and clear fragcolor
                float4 O = 0;
                float4 h; O = 0.9;
                float2 I = i.vertex.xy;
                
                //Uvs and resolution for scaling
                float2 u, r = _ScreenParams.xy;
                
                //Alpha, length, angle and iterator/radius
                for(float A,l,L,a,i=7.;--i>0.;
                        //A = anti-aliased alpha using SDF
                        //Pick layer color
                        O=lerp(h=sin(i+a/3.+float4(1,3,5,0))*.2+.7,O, A=min(--l*r.y*.02,1.))*
                        //Soft shading
                        (l + h + .5*A*u.y/L )/L)
                    
                    //Smoothly rotate a quarter at a time
                    a-=sin(a-=sin(a=_Time.y*4.+i*.4)),
                    //Scale and center
                    u=(I+I-r)/r.y/.1,
                    //Compute round square SDF
                    L = l = max(length(u -= mul(R, clamp(mul(u, R),-i,i))),1.);

                return O;
            }
            ENDHLSL
        }
    }
}

/*
    https://www.shadertoy.com/view/ctGyWK
    "Origami" by @XorDev

    I wanted to try out soft shading like paper,
    but quickly discovered it looks better with
    color and looks like bounce lighting!

    X : X.com/XorDev/status/1727206969038213426
    Twigl: twigl.app?ol=true&ss=-NjpcsfowUETZLMr_Ki6

    <512 char playlist: shadertoy.com/playlist/N3SyzR
    Thanks to FabriceNeyret2 for many tricks
*/
//Rotate trick
//#define R mat2(cos(a/4.+vec4(0,11,33,0)))
//
//void mainImage(out vec4 O, vec2 I )
//{
//    //Initialize hue and clear fragcolor
//    vec4 h; O=++h;
//    
//    //Uvs and resolution for scaling
//    vec2 u,r=iResolution.xy;
//    //Alpha, length, angle and iterator/radius
//    for(float A,l,L,a,i=7.;--i>0.;
//            //A = anti-aliased alpha using SDF
//            //Pick layer color
//            O=mix(h=sin(i+a/3.+vec4(1,3,5,0))*.2+.7,O, A=min(--l*r.y*.02,1.))*
//            //Soft shading
//            (l + h + .5*A*u.y/L )/L)
//        
//        //Smoothly rotate a quarter at a time
//        a-=sin(a-=sin(a=iTime*4.+i*.4)),
//        //Scale and center
//        u=(I+I-r)/r.y/.1,
//        //Compute round square SDF
//        L = l = max(length(u -= R*clamp(u*R,-i,i)),1.);
//        
//        
//}