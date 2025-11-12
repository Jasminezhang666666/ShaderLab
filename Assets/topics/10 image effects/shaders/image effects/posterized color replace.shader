Shader "shader lab/week 10/posterized color replace" {
    Properties {
        _steps ("steps", Range(1, 16)) = 16
        _recolor ("recolor reference", 2D) = "black" {}
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
            int _steps;
            CBUFFER_END

            TEXTURE2D(_recolor);
            
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

            float get_luminance(float3 c) {
                float3 w = float3(0.2126, 0.7152, 0.0722);
                // c.x * w.x + c.y * w.y + c.z * w.z;
                return dot(c, w);
            }
            
            float4 frag (Interpolators i) : SV_Target {
                float2 uv = i.uv;
                float3 color = 0;

                color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv);
                float lum = get_luminance(color);

                // posterization
                lum = floor(lum * _steps) / _steps;

                color = SAMPLE_TEXTURE2D(_recolor, sampler_PointClamp, float2(lum , 0.5));
                
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}