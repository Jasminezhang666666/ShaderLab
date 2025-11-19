Shader "shader lab/week 11/depth" {
    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        
        // depth only pass
        Pass {
            Tags { "LightMode"="DepthOnly" }
            
            ZWrite On
            ColorMask 0
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
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
                return 0;
            }
            ENDHLSL
        } 
        

        // main color pass
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

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

                float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV);
                depth = Linear01Depth(depth, _ZBufferParams);

                color = depth.rrr;
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}