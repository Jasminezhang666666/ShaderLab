Shader "shader lab/week 8/normal mapping" {
    Properties {
        _albedo ("albedo", 2D) = "white" {}
        [NoScaleOffset] _normalMap ("normal map", 2D) = "bump" {}
        _gloss ("gloss", Range(0,1)) = 1
        _normalIntensity ("normal intensity", Range(0,1)) = 1
        [Toggle] _toggle ("toggle", Float) = 1
    }
    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #define MAX_SPECULAR_POWER 256
            
            CBUFFER_START(UnityPerMaterial)
            float4 _albedo_ST;
            float _gloss;
            float _normalIntensity;
            CBUFFER_END

            TEXTURE2D(_albedo);
            SAMPLER(sampler_albedo);

            TEXTURE2D(_normalMap);
            SAMPLER(sampler_normalMap);

            struct MeshData {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float3 tangent : TEXCOORD2;
                float3 bitangent : TEXCOORD3;
                float3 worldPos : TEXCOORD4;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                
                o.uv = TRANSFORM_TEX(v.uv, _albedo);
                
                o.normal = TransformObjectToWorldNormal(v.normal);
                o.tangent = TransformObjectToWorldNormal(v.tangent.xyz);

                o.bitangent = cross(o.normal, o.tangent.xyz) * v.tangent.w;

                
                o.vertex = TransformObjectToHClip(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);

                return o;
            }

            float3 blinnphong (float2 uv, float3 normal, float3 worldPos) {
                float3 surfaceColor = SAMPLE_TEXTURE2D(_albedo, sampler_albedo, uv).rgb;

                Light light = GetMainLight();
                
                // blinn-phong
                float3 viewDirection = normalize(GetCameraPositionWS() - worldPos);
                float3 halfDirection = normalize(viewDirection + light.direction);

                float diffuseFalloff = max(0, dot(normal, light.direction));
                float specularFalloff = max(0, dot(normal, halfDirection));

                float3 diffuse = diffuseFalloff * surfaceColor * light.color;

                // the specular power, which controls the sharpness of the direct specular light is dependent on the glossiness (smoothness)
                float3 specular = pow(specularFalloff, _gloss * MAX_SPECULAR_POWER + 1) * _gloss * light.color;

                return diffuse + specular;
            }

            float4 frag (Interpolators i) : SV_Target {
                float2 uv = i.uv;
                float3 color = 0;
                

                float3 normal = normalize(i.normal);


                float3 tangentSpaceNormal = UnpackNormal(SAMPLE_TEXTURE2D(_normalMap, sampler_normalMap, uv));

                tangentSpaceNormal = lerp(float3(0, 0, 1), tangentSpaceNormal, _normalIntensity);
                
                float3x3 tangentToWorld = float3x3 (
                    i.tangent.x, i.bitangent.x, i.normal.x,
                    i.tangent.y, i.bitangent.y, i.normal.y,
                    i.tangent.z, i.bitangent.z, i.normal.z
                );

                
                normal = mul(tangentToWorld, tangentSpaceNormal);
                
                color = blinnphong(uv, normal, i.worldPos);
                
                
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}