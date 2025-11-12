Shader "shader lab/week 10/chromatic aberration" {
    Properties {
        _intensity("intensity", Range(0,1)) = 0.2
    }
    SubShader {
        Tags { "RenderPipeline"="UniversalPipeline" }
        
        Cull Off
        ZWrite Off
        ZTest Always

        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #define MAX_OFFSET 0.15

            CBUFFER_START(UnityPerMaterial)
            float _intensity;
            CBUFFER_END

            TEXTURE2D(_BlitTexture);
            SAMPLER(sampler_BlitTexture);
            
            struct MeshData {
                uint vertexID : SV_VertexID;
            };

            struct Interpolators {
                float4 posCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.posCS = GetFullScreenTriangleVertexPosition(v.vertexID);
                o.uv    = GetFullScreenTriangleTexCoord   (v.vertexID);
                return o;
            }
            
            float4 frag (Interpolators i) : SV_Target {
                float2 uv = i.uv;
                float3 color = 0;
                
                float2 offset = float2(_intensity * MAX_OFFSET, 0);
                
                float r = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv + offset).r;
                float g = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv).g;
                float b = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv - offset).b;

                color = float3(r, g, b);
                
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}