Shader "shader lab/week 11/soldierXRay_HW11"
{
    Properties
    {
        _BaseMap   ("Base Map", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)

        _Metallic  ("Metallic", Range(0,1)) = 0.0
        _Smoothness("Smoothness", Range(0,1)) = 0.5

        _AmbientColor ("Ambient Color", Color) = (0.05, 0.05, 0.05, 1)

        _stencilRef ("Stencil Reference", Int) = 2
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "Queue"          = "Geometry"
        }

        //PASS 1: FRONT FACES, OUTSIDE X-RAY VOLUMES
        Pass
        {
            Cull Back

            Stencil
            {
                Ref  [_stencilRef]
                Comp NotEqual // draw where stencil != 2 (outside knife)
            }

            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseColor;
            float  _Metallic;
            float  _Smoothness;
            float4 _AmbientColor;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            struct MeshData
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv     : TEXCOORD0;
            };

            struct Interpolators
            {
                float4 vertex   : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float2 uv       : TEXCOORD2;
            };

            Interpolators vert (MeshData v)
            {
                Interpolators o;
                o.vertex   = TransformObjectToHClip(v.vertex);
                o.normalWS = TransformObjectToWorldNormal(v.normal);
                o.worldPos = TransformObjectToWorld(v.vertex).xyz;
                o.uv       = v.uv;
                return o;
            }

            float4 frag (Interpolators i) : SV_Target
            {
                float3 albedoTex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv).rgb;
                float3 albedo    = albedoTex * _BaseColor.rgb;

                float3 N = normalize(i.normalWS);
                float3 V = normalize(GetCameraPositionWS() - i.worldPos);

                Light mainLight = GetMainLight();
                float3 L = normalize(mainLight.direction);
                float3 H = normalize(L + V);

                // Diffuse term (Lambert)
                float ndotl = saturate(dot(N, L));
                float3 diffuse = ndotl * albedo * mainLight.color;

                // Blinn specular
                float ndoth = saturate(dot(N, H));
                float specPow = lerp(8.0, 128.0, _Smoothness);
                float spec    = pow(ndoth, specPow);
                float3 specularColor = lerp(float3(0.04, 0.04, 0.04), albedo, _Metallic);
                float3 specular = spec * specularColor * mainLight.color;

                float3 ambient = _AmbientColor.rgb * albedo;

                float3 color = diffuse + specular + ambient;
                return float4(color, 1.0);
            }
            ENDHLSL
        }

        // PASS 2: BACK FACES, INSIDE X-RAY VOLUMES
        Pass
        {
            Cull Front // backfaces only

            Stencil
            {
                Ref  [_stencilRef]
                Comp Equal // draw where stencil == 2 (inside cylinders)
            }

            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseColor;
            float  _Metallic;
            float  _Smoothness;
            float4 _AmbientColor;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            struct MeshData
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv     : TEXCOORD0;
            };

            struct Interpolators
            {
                float4 vertex   : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float2 uv       : TEXCOORD2;
            };

            Interpolators vert (MeshData v)
            {
                Interpolators o;
                o.vertex   = TransformObjectToHClip(v.vertex);
                o.normalWS = TransformObjectToWorldNormal(v.normal);
                o.worldPos = TransformObjectToWorld(v.vertex).xyz;
                o.uv       = v.uv;
                return o;
            }

            float4 frag (Interpolators i) : SV_Target
            {
                float3 albedoTex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv).rgb;
                float3 albedo    = albedoTex * _BaseColor.rgb;

                float3 N = normalize(i.normalWS);
                float3 V = normalize(GetCameraPositionWS() - i.worldPos);

                Light mainLight = GetMainLight();
                float3 L = normalize(mainLight.direction);
                float3 H = normalize(L + V);

                float ndotl = saturate(dot(N, L));
                float3 diffuse = ndotl * albedo * mainLight.color;

                float ndoth = saturate(dot(N, H));
                float specPow = lerp(8.0, 128.0, _Smoothness);
                float spec    = pow(ndoth, specPow);
                float3 specularColor = lerp(float3(0.04, 0.04, 0.04), albedo, _Metallic);
                float3 specular = spec * specularColor * mainLight.color;

                float3 ambient = _AmbientColor.rgb * albedo;

                float3 color = diffuse + specular + ambient;
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
