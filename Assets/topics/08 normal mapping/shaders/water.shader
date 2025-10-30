Shader "shader lab/week 8/water" {
    Properties {
        _albedo ("albedo", 2D) = "white" {}
        [NoScaleOffset] _normalMap ("normal map", 2D) = "bump" {}
        [NoScaleOffset] _displacementMap ("displacement map", 2D) = "white" {}
        _gloss ("gloss", Range(0,1)) = 1
        _normalIntensity ("normal intensity", Range(0, 1)) = 1
        _displacementIntensity ("displacement intensity", Range(0,1)) = 0.5
        _refractionIntensity ("refraction intensity", Range(0, 0.5)) = 0.1
        _opacity ("opacity", Range(0,1)) = 0.9
    }
    SubShader {
        // this shader won't actually use transparency, but we want it to render with the transparent objects
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
            float _gloss;
            float _normalIntensity;
            float _displacementIntensity;
            float _refractionIntensity;
            float _opacity;

            float4 _albedo_ST;
            CBUFFER_END

            TEXTURE2D(_albedo);
            SAMPLER(sampler_albedo);
            
            TEXTURE2D(_normalMap);
            SAMPLER(sampler_normalMap);
            
            TEXTURE2D(_displacementMap);
            SAMPLER(sampler_displacementMap);

            // frame buffer of opaque objects made availble by going to:
            // universal render pipeline asset > opaque texture
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
                
                // create a variable to hold two float2 direction vectors that we'll use to pan our textures
                float4 uvPan : TEXCOORD5;
                float4 screenUV : TEXCOORD6;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.uv = TRANSFORM_TEX(v.uv, _albedo);
                
                // panning
                o.uvPan = float4(float2(0.9, 0.2) * _Time.x, float2(0.5, -0.2) * _Time.x);

                // add our panning to our displacement texture sample
                float height = _displacementMap.SampleLevel(sampler_displacementMap, o.uv + o.uvPan.xy, 0).r;
                v.vertex.xyz += v.normal * height * _displacementIntensity;

                o.normal = TransformObjectToWorldNormal(v.normal);
                o.tangent = TransformObjectToWorldNormal(v.tangent);
                o.bitangent = cross(o.normal, o.tangent) * v.tangent.w;

                o.vertex = TransformObjectToHClip(v.vertex);
                
                o.screenUV = ComputeScreenPos(o.vertex);
                
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);
                
                return o;
            }

            float4 frag (Interpolators i) : SV_Target {
                float2 uv = i.uv;
                float2 screenUV = i.screenUV.xy / i.screenUV.w;
                
                float3 tangentSpaceNormal = UnpackNormal(_normalMap.Sample(sampler_normalMap, uv + i.uvPan.xy));
                float3 tangentSpaceDetailNormal = UnpackNormal(_normalMap.Sample(sampler_normalMap, (uv * 5) + i.uvPan.zw));

                // blending normals together whiteout blend
                tangentSpaceNormal = BlendNormalRNM(tangentSpaceNormal, tangentSpaceDetailNormal);
                
                
                tangentSpaceNormal = normalize(lerp(float3(0, 0, 1), tangentSpaceNormal, _normalIntensity));
                
                float2 refractionUV = screenUV.xy + (tangentSpaceNormal.xy * _refractionIntensity);
                float3 background = _CameraOpaqueTexture.Sample(sampler_CameraOpaqueTexture, refractionUV);

                float3x3 tangentToWorld = float3x3 
                (
                    i.tangent.x, i.bitangent.x, i.normal.x,
                    i.tangent.y, i.bitangent.y, i.normal.y,
                    i.tangent.z, i.bitangent.z, i.normal.z
                );

                float3 normal = mul(tangentToWorld, tangentSpaceNormal);
                
                // blinn phong
                float3 surfaceColor = _albedo.Sample(sampler_albedo, uv + i.uvPan.xy).rgb;

                Light light = GetMainLight();
                
                float3 viewDirection = normalize(GetCameraPositionWS() - i.posWorld);
                float3 halfDirection = normalize(viewDirection + light.direction);

                float diffuseFalloff = max(0, dot(normal, light.direction));
                float specularFalloff = max(0, dot(normal, halfDirection));

                float3 specular = pow(specularFalloff, _gloss * MAX_SPECULAR_POWER + 1) * _gloss * light.color;
                float3 diffuse = diffuseFalloff * surfaceColor * light.color;

                float3 finalColor = lerp(background, diffuse, _opacity) + specular;
                
                return float4(finalColor, 1);
            }
            ENDHLSL
        }
    }
}