Shader "shader lab/week 11/object" {
    Properties {
        _surfaceColor ("surface color", Color) = (0.4, 0.1, 0.9)
        _gloss ("gloss", Range(0,1)) = 1
        _diffuseLightSteps ("diffuse light steps", Int) = 4
        _specularLightSteps ("specular light steps", Int) = 2
        _ambientColor ("ambient color", Color) = (0.7, 0.05, 0.15)
    }
    SubShader {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }
        
        
        // nothing new below
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
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.normal = TransformObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                
                return o;
            }

            float4 frag (Interpolators i) : SV_Target {
                float3 color = 0;
                float3 normal = normalize(i.normal);
                Light light = GetMainLight();

                // blinn-phong
                float3 viewDirection = normalize(GetCameraPositionWS() - i.worldPos);
                float3 halfDirection = normalize(viewDirection + light.direction);

                float diffuseFalloff = max(0, dot(normal, light.direction));
                float specularFalloff = max(0, dot(normal, halfDirection));

                specularFalloff = pow(specularFalloff, _gloss * MAX_SPECULAR_POWER + 1) * _gloss;
                
                diffuseFalloff  = ceil (diffuseFalloff  * _diffuseLightSteps ) / _diffuseLightSteps;
                specularFalloff = floor(specularFalloff * _specularLightSteps) / _specularLightSteps;

                float3 diffuse = diffuseFalloff * _surfaceColor * light.color;
                float3 specular = specularFalloff * light.color;

                color = diffuse + specular + _ambientColor;

                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}