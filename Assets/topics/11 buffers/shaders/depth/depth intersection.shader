Shader "shader lab/week 11/depth intersection" {
    Properties {
        
    }

    SubShader {
        Tags{
            "RenderPipeline" = "UniversalPipeline"
        }
        
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
            
            CBUFFER_END

            // declare depth texture
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            
            struct MeshData {
                float4 vertex : POSITION;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
                float4 screenPos : TEXCOORD0;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.screenPos = ComputeScreenPos(o.vertex);
                
                return o;
            }

            float4 frag (Interpolators i) : SV_Target {
                float3 color = 0;
                float2 screenUV = i.screenPos.xy / i.screenPos.w;

                float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r;
                depth = Linear01Depth(depth, _ZBufferParams);
                
                
                return float4(color, 1);
            }
            ENDHLSL
        }
    }
}