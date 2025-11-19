Shader "shader lab/week 11/depth intersection" {
    Properties {
        _size ("intersection size", Range(0.1, 1)) = 0.2
    }

    SubShader {
        Tags{
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"
        }
        
        Blend One One
        Cull Off
        
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
            float _size;
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
                float surfZ : TEXCOORD1;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.surfZ = -mul(UNITY_MATRIX_MV, v.vertex).z;
                
                o.screenPos = ComputeScreenPos(o.vertex);
                
                return o;
            }

            float4 frag (Interpolators i) : SV_Target {
                float3 color = 0;
                float2 screenUV = i.screenPos.xy / i.screenPos.w;

                float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r;
                depth = Linear01Depth(depth, _ZBufferParams);

                float difference = abs((depth / _ProjectionParams.w) - i.surfZ);

                color = smoothstep(_size, 0, difference).rrr;
                
                return float4(color, 1);
            }
            ENDHLSL
        }
    }
}