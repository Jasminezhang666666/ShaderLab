Shader "shader lab/week 10/box blur" {
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

            CBUFFER_START(UnityPerMaterial)
            float4 _BlitTexture_TexelSize;
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
                o.uv    = GetFullScreenTriangleTexCoord(v.vertexID);
                return o;
            }
            
            float4 frag (Interpolators i) : SV_Target {
                float2 uv = i.uv;
                float3 color = 0;

                float3x3 boxBlurKernel = float3x3 (
                    0.11, 0.11, 0.11,
                    0.11, 0.11, 0.11,
                    0.11, 0.11, 0.11
                );

                float2 ts = _BlitTexture_TexelSize.xy;
                for (int x = -1; x <= 1; x++) {
                    for (int y = -1; y <= 1; y++) {
                        float2 offset = float2(x, y) * ts;
                        float3 sample = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv + offset);

                        color += sample * boxBlurKernel[x+1][y+1];
                    }
                }
                
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}