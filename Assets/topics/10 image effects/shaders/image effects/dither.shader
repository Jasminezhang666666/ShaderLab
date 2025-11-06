Shader "shader lab/week 10/dither" {
    Properties{

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

            float get_luminance (float3 color) {
                float3 channelWeight = float3(0.2126, 0.7152, 0.0722);
                return dot(color, channelWeight);
            }
            
            float4 frag (Interpolators i) : SV_Target {
                float2 uv = i.uv;
                float color = 0;
                
                return float4(color.rrr, 1.0);
            }
            ENDHLSL
        }
    }
}