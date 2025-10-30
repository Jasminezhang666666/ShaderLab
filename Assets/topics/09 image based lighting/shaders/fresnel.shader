Shader "shader lab/week 9/fresnel" {
    Properties {
        [NoScaleOffset] _IBL ("IBL cube map", Cube) = "black" {}
        
        // smoothness of surface - sharpness of reflection
        _gloss ("gloss", Range(0,1)) = 1

        // reflectivity of surface - brightness of reflection
        _reflectivity ("reflectivity", Range(0,1)) = 0.5
    }
    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #define SPECULAR_MIP_STEPS 4

            CBUFFER_START(UnityPerMaterial)
            float _gloss;
            float _reflectivity;
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
                float3 normal = i.normal;

                float3 viewDirection = normalize(GetCameraPositionWS() - i.worldPos);
                float3 viewReflection = reflect(-viewDirection, normal);
                
                float mip = (1 - _gloss) * SPECULAR_MIP_STEPS;
                float3 indirectSpecular = SAMPLE_TEXTURECUBE_LOD(_IBL, sampler_IBL, viewReflection, mip) * _reflectivity;
                
                
                color = indirectSpecular;

                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}