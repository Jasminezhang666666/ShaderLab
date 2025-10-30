Shader "shader lab/week 4/white noise" {
    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct MeshData {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }  

            float4 frag (Interpolators i) : SV_Target {
                float2 uv = i.uv;

                float wn = 0;

                uv = floor(uv * 128);
                
                float uvDot = dot(uv, float2(128.239, -78.381));
                wn = frac(sin(uvDot) * 437587.5453);

                return float4(wn.rrr, 1.0);
            }
            ENDHLSL
        }
    }
}