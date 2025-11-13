Shader "shader lab/week 11/posterized" {
    Properties {
        _surfaceColor ("surface color", Color) = (0.4, 0.1, 0.9)
        _gloss ("gloss", Range(0,1)) = 1
        _diffuseLightSteps ("diffuse light steps", Int) = 4
        _specularLightSteps ("specular light steps", Int) = 2
        _ambientColor ("ambient color", Color) = (0.7, 0.05, 0.15)
    }
    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass {
            Tags { "LightMode" = "DepthOnly" }

            // Write depth to the depth buffer
            ZWrite On

            // Don't write to the color buffer
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

        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #define MAX_SPECULAR_POWER 256

            CBUFFER_START(UnityPerMaterial)
            float3 _surfaceColor;
            float _gloss;
            int _diffuseLightSteps;
            int _specularLightSteps;
            float3 _ambientColor;
            CBUFFER_END

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

                o.normal = TransformObjectToWorldNormal(v.normal);
                o.vertex = TransformObjectToHClip(v.vertex);

                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                
                o.uv = v.uv;
                return o;
            }

            float4 frag (Interpolators i) : SV_Target {
                float2 uv = i.uv;

                float3 normal = normalize(i.normal);

                Light light = GetMainLight();

                // blinn-phong
                // calculates "half direction" and compares it to normal 
                float3 viewDirection = normalize(GetCameraPositionWS() - i.worldPos);
                float3 halfDirection = normalize(viewDirection + light.direction);

                float diffuseFalloff = max(0, dot(normal, light.direction));
                float specularFalloff = max(0, dot(normal, halfDirection));

                float3 specular = pow(specularFalloff, _gloss * MAX_SPECULAR_POWER + 0.0001) * light.color * _gloss;
                
                // posterization
                diffuseFalloff = floor(diffuseFalloff * _diffuseLightSteps) / _diffuseLightSteps;
                specular = floor(specular * _specularLightSteps) / _specularLightSteps;
                
                float3 posterizedBlinnPhong = diffuseFalloff * _surfaceColor * light.color + specular + _ambientColor;

                return float4(posterizedBlinnPhong, 1.0);
            }
            ENDHLSL
        }
    }
}