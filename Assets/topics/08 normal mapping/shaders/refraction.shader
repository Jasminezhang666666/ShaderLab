Shader "shader lab/week 8/refraction" {
    Properties {
        _tint ("tint color", Color) = (1, 1, 1, 1)
        _albedo ("albedo", 2D) = "white" {}
        [NoScaleOffset] _normalMap ("normal map", 2D) = "bump" {}
        [NoScaleOffset] _displacementMap ("displacement map", 2D) = "gray" {}
        _gloss ("gloss", Range(0,1)) = 1
        _normalIntensity ("normal intensity", Range(0, 1)) = 1
        _displacementIntensity ("displacement intensity", Range(0, 0.5)) = 0
        _refractionIntensity ("refraction intensity", Range(0, 0.5)) = 0.5
        _opacity ("opacity", Range(0,1)) = 1
    }
    SubShader {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
        }
        
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #define MAX_SPECULAR_POWER 256
            
            CBUFFER_START(UnityPerMaterial)
            float3 _tint;
            float _gloss;
            float _normalIntensity;
            float _displacementIntensity;
            float _opacity;
            float _refractionIntensity;
            float4 _albedo_ST;
            CBUFFER_END
                       
            TEXTURE2D(_albedo);
            SAMPLER(sampler_albedo);
            
            TEXTURE2D(_normalMap);
            SAMPLER(sampler_normalMap);
            
            TEXTURE2D(_displacementMap);
            SAMPLER(sampler_displacementMap);

            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);
            
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
                float3 posWorld : TEXCOORD4;
                float4 screenUV : TEXCOORD5;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.uv = TRANSFORM_TEX(v.uv, _albedo);
                
                o.normal = TransformObjectToWorldNormal(v.normal);
                o.tangent = TransformObjectToWorldNormal(v.tangent);
                o.bitangent = cross(o.normal, o.tangent) * v.tangent.w;
                
                float height = SAMPLE_TEXTURE2D_LOD(_displacementMap, sampler_displacementMap, o.uv, 0).r;
                v.vertex.xyz += v.normal * height * _displacementIntensity;
                
                o.vertex = TransformObjectToHClip(v.vertex);
                o.screenUV = ComputeScreenPos(o.vertex); // clip space vertex position only

                o.posWorld = mul(unity_ObjectToWorld, v.vertex);
                
                return o;
            }

            float4 frag (Interpolators i) : SV_Target {
                float2 uv = i.uv;
                float3 color = 0;

                float2 screenUV = i.screenUV.xy / i.screenUV.w;
                
                
                float3 tangentSpaceNormal = UnpackNormal(SAMPLE_TEXTURE2D(_normalMap, sampler_normalMap, uv));
                tangentSpaceNormal = normalize(lerp(float3(0, 0, 1), tangentSpaceNormal, _normalIntensity));



                float2 refractionUV = screenUV.xy + (tangentSpaceNormal.xy * _refractionIntensity);
                float3 background = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, refractionUV);

                
                float3x3 tangentToWorld = float3x3 (
                    i.tangent.x, i.bitangent.x, i.normal.x,
                    i.tangent.y, i.bitangent.y, i.normal.y,
                    i.tangent.z, i.bitangent.z, i.normal.z
                );

                float3 normal = normalize(mul(tangentToWorld, tangentSpaceNormal));
                
                // blinn phong
                float3 surfaceColor = SAMPLE_TEXTURE2D(_albedo, sampler_albedo, uv).rgb;

                Light light = GetMainLight();

                float3 viewDirection = normalize(GetCameraPositionWS() - i.posWorld);
                float3 halfDirection = normalize(viewDirection + light.direction);

                float diffuseFalloff = max(0, dot(normal, light.direction));
                float specularFalloff = max(0, dot(normal, halfDirection));

                float3 specular = pow(specularFalloff, _gloss * MAX_SPECULAR_POWER + 1) * light.color * _gloss;
                float3 diffuse = diffuseFalloff * surfaceColor * light.color * _tint;

                color = lerp(background, diffuse, _opacity) + specular;
                
                return float4(color, 1);
            }
            ENDHLSL
        }
    }
}