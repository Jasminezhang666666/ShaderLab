Shader "shader lab/week 10/IBL fresnel and roughness" {
    Properties {
        _albedo ("albedo", 2D) = "white" {}
        [NoScaleOffset] _normalMap ("normal map", 2D) = "bump" {}
        [NoScaleOffset] _displacementMap ("displacement map", 2D) = "gray" {}
        [NoScaleOffset] _roughness ("roughness map", 2D) = "white"
        [NoScaleOffset] _IBL ("IBL cube map", Cube) = "black" {}

        // brightness of specular reflection - proportion of color contributed by diffuse and specular
        // reflectivity at 1, color is all specular
        _reflectivity ("reflectivity", Range(0,1)) = 0.5

        _fresnelPower ("fresnel power", Range(0, 10)) = 5
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
            float _reflectivity;
            float _fresnelPower;
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

            TEXTURE2D(_roughness);
            SAMPLER(sampler_roughness);
            
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
                float3 posWorld : TEXCOORD4;
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
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);
                
                return o;
            }

            float4 frag (Interpolators i) : SV_Target {
                float3 color = 0;
                float2 uv = i.uv;

                float3 tangentSpaceNormal = UnpackNormal(SAMPLE_TEXTURE2D(_normalMap, sampler_normalMap, uv));
                tangentSpaceNormal = normalize(lerp(float3(0, 0, 1), tangentSpaceNormal, _normalIntensity));
                
                float3x3 tangentToWorld = float3x3 (
                    i.tangent.x, i.bitangent.x, i.normal.x,
                    i.tangent.y, i.bitangent.y, i.normal.y,
                    i.tangent.z, i.bitangent.z, i.normal.z
                );

                float3 normal = mul(tangentToWorld, tangentSpaceNormal);
                
                // since the diffuse and reflective properties of an object are inversely related, we want to set up our surface color to lerp between black and the albedo based on the inverse of reflectivity
                // if 0% reflective -> all diffuse
                float3 surfaceColor = lerp(0, SAMPLE_TEXTURE2D(_albedo, sampler_albedo, uv).rgb, 1 - _reflectivity);

                Light light = GetMainLight();
                
                float3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.posWorld);
                float fresnel = 1 - saturate(dot(viewDirection, normal));
                fresnel = pow(fresnel, _fresnelPower);

                // since fresnel affects reflectivity, we'll use it to modify the reflectivity variable
                float reflectivity = _reflectivity * fresnel;
                
                // make view direction negative because reflect takes an incidence vector meanining, it is point toward the surface
                // viewDirection is pointing toward the camera
                float3 viewReflection = reflect(-viewDirection, normal);
                
                // roughness is the inverse of gloss (gloss = 1-roughness)
                float roughness = SAMPLE_TEXTURE2D(_roughness, sampler_roughness, uv).r;
                // roughness value corresponds to how smooth or rough a surface is
                // the smoother the surface the sharper the specular reflection
                float mip = roughness * SPECULAR_MIP_STEPS;
                float3 indirectSpecular = SAMPLE_TEXTURECUBE_LOD(_IBL, sampler_IBL, viewReflection, mip);

                float3 halfDirection = normalize(viewDirection + light.direction);

                float directDiffuse = max(0, dot(normal, light.direction));
                float specularFalloff = max(0, dot(normal, halfDirection));
                
                // the specular power, which controls the sharpness of the direct specular light is dependent on the glossiness (smoothness)
                float3 directSpecular = pow(specularFalloff, (1 - roughness) * MAX_SPECULAR_POWER + 0.0001) * light.color * (1 - roughness);
                float3 specular = directSpecular + indirectSpecular * reflectivity;
                
                float3 indirectDiffuse = SAMPLE_TEXTURECUBE_LOD(_IBL, sampler_IBL, normal, DIFFUSE_MIP_LEVEL);
                float3 diffuse = surfaceColor * (directDiffuse * light.color + indirectDiffuse);

                color = diffuse + specular;

                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}