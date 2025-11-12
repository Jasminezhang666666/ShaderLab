Shader "shader lab/week 10/lens distortion" {
    Properties {
        _distortion ("distortion", Range(-1, 10)) = 4
        _scale ("scale", Range(0.01, 5)) = 1
    }
    SubShader {
        Tags { "RenderPipeline"="UniversalPipeline" }
        
        ZWrite Off
        Cull Off
        ZTest Always
        
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float _distortion;
            float _scale;
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

                uv -= 0.5;
                uv *= _scale;

                float radius = pow(length(uv), 2);
                float distort = 1 + radius * _distortion;
                uv = uv * distort + 0.5;

                color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearRepeat, uv);
                
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}