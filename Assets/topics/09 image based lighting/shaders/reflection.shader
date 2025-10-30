Shader "shader lab/week 9/reflection" {
    Properties {
        [NoScaleOffset] _IBL ("IBL cube map", Cube) = "black" {}
        
        // smoothness of surface - sharpness of reflection
        _gloss ("gloss", Range(0,1)) = 1
        
    }
    SubShader {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "LightMode" = "UniversalForward"
        }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            

            CBUFFER_START(UnityPerMaterial)
            float _gloss;
            CBUFFER_END

            TEXTURECUBE(_IBL);
            SAMPLER(sampler_IBL);
            
            struct MeshData {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.uv = v.uv;

                o.normal = TransformObjectToWorldNormal(v.normal);

                o.vertex = TransformObjectToHClip(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                
                return o;
            }

            float4 frag (Interpolators i) : SV_Target {
                float3 color = 0;
                float3 normal = normalize(i.normal);

                float3 viewDirection = normalize(GetCameraPositionWS() - i.worldPos);
                

                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}