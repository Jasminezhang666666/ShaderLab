Shader "shader lab/week 9/specular IBL" {
    Properties {
        _albedo ("albedo", 2D) = "white" {}
        [NoScaleOffset] _normalMap ("normal map", 2D) = "bump" {}
        [NoScaleOffset] _displacementMap ("displacement map", 2D) = "gray" {}
        [NoScaleOffset] _IBL ("IBL cube map", Cube) = "black" {}
        
        // how smooth the surface is - sharpness of specular reflection
        _gloss ("gloss", Range(0,1)) = 1

        // brightness of specular reflection - proportion of color contributed by diffuse and specular
        // reflectivity at 1, color is all specular
        _reflectivity ("reflectivity", Range(0,1)) = 0.5

        _normalIntensity ("normal intensity", Range(0, 1)) = 1
        _displacementIntensity ("displacement intensity", Range(0, 0.5)) = 0
    }
    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #define DIFFUSE_MIP_LEVEL 5
            #define SPECULAR_MIP_STEPS 4
            #define MAX_SPECULAR_POWER 256
            
            CBUFFER_START(UnityPerMaterial)
            float _gloss;
            float _reflectivity;
            float _normalIntensity;
            float _displacementIntensity;

            float4 _albedo_ST;
            CBUFFER_END

            TEXTURE2D(_albedo);
            SAMPLER(sampler_albedo);

            TEXTURE2D(_normalMap);
            SAMPLER(sampler_normalMap);

            TEXTURE2D(_displacementMap);
            SAMPLER(sampler_displacementMap);
            
            TEXTURECUBE(_IBL);
            SAMPLER(sampler_IBL);
            
            struct MeshData {
                float4 vertex : POSITION;
                float3 normal : NORMAL;

                // xyz is the tangent direction, w is the tangent sign
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
                
                float height = SAMPLE_TEXTURE2D_LOD(_displacementMap, sampler_displacementMap, o.uv, 0).r;
                v.vertex.xyz += v.normal * height * _displacementIntensity;

                o.normal = TransformObjectToWorldNormal(v.normal);
                o.tangent = TransformObjectToWorldNormal(v.tangent);
                o.bitangent = cross(o.normal, o.tangent) * v.tangent.w;
                
                o.vertex = TransformObjectToHClip(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                
                return o;
            }

            // construct our tangent space matrix and sample our normal map
            float3 get_normal (Interpolators i) {
                float3 tangentSpaceNormal = UnpackNormal(SAMPLE_TEXTURE2D(_normalMap, sampler_normalMap, i.uv));
                tangentSpaceNormal = normalize(lerp(float3(0, 0, 1), tangentSpaceNormal, _normalIntensity));
                
                float3x3 tangentToWorld = float3x3 (
                    i.tangent.x, i.bitangent.x, i.normal.x,
                    i.tangent.y, i.bitangent.y, i.normal.y,
                    i.tangent.z, i.bitangent.z, i.normal.z
                );

                return mul(tangentToWorld, tangentSpaceNormal);
            }

            // function to claculate direct diffuse and direct specular falloff
            // r: diffuse falloff
            // g: specular falloff
            float2 lighting_falloff (Interpolators i, float3 normal) {
                Light light = GetMainLight();
                
                float3 viewDirection = normalize(GetCameraPositionWS() - i.worldPos);
                float3 halfDirection = normalize(viewDirection + light.direction);

                float directDiffuse = max(0, dot(normal, light.direction));
                float directSpecular = max(0, dot(normal, halfDirection));
                directSpecular = pow(directSpecular, _gloss * MAX_SPECULAR_POWER + 1) * _gloss;

                return float2(directDiffuse, directSpecular);
            }

            float4 frag (Interpolators i) : SV_Target {
                float3 color = 0;
                float3 normal = get_normal(i);

                float2 directFalloff = lighting_falloff(i, normal);
                float directDiffuseFalloff  = directFalloff.r;
                float directSpecularFalloff = directFalloff.g;
                
                // INDIRECT DIFFUSE
                float3 indirectDiffuse = SAMPLE_TEXTURECUBE_LOD(_IBL, sampler_IBL, normal, DIFFUSE_MIP_LEVEL);
                
                // INDIRECT SPECULAR
                float3 viewDirection = normalize(GetCameraPositionWS() - i.worldPos);
                float3 viewReflection = reflect(-viewDirection, normal);
                
                float mip = (1-_gloss) * SPECULAR_MIP_STEPS;
                float3 indirectSpecular = SAMPLE_TEXTURECUBE_LOD(_IBL, sampler_IBL, viewReflection, mip);
                
                
                float3 surfaceColor = SAMPLE_TEXTURE2D(_albedo, sampler_albedo, i.uv).rgb * (1 - _reflectivity);

                Light light = GetMainLight();
                // sum up all incoming light (direct + indirect) then multiply by the surface color, because the surface color still fully determines what light gets absorbed/reflected
                float3 diffuse = surfaceColor * (directDiffuseFalloff * light.color + indirectDiffuse);

                float3 directSpecular = light.color * directSpecularFalloff;
                float3 specular = directSpecular + indirectSpecular * _reflectivity;
                
                color = diffuse + specular;
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}