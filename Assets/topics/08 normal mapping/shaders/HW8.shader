Shader "shader lab/week 8/HW8_water" 
{
    Properties
    {
        _albedo ("albedo", 2D) = "white" {}
        [NoScaleOffset] _normalMap ("normal map", 2D) = "bump" {}
        [NoScaleOffset] _displacementMap ("displacement map", 2D) = "white" {}

        _gloss ("gloss", Range(0,1)) = 1
        _normalIntensity ("normal intensity", Range(0, 1)) = 1
        _displacementIntensity ("displacement intensity", Range(0,1)) = 0.5
        _refractionIntensity ("refraction intensity", Range(0, 0.5)) = 0.12

        // legacy note; alpha now driven by Fresnel + foam
        _opacity ("opacity (legacy - not used for alpha)", Range(0,1)) = 0.9

        // Base look controls
        _tint ("tint", Color) = (0.65, 0.9, 1.0, 1)
        _surfaceAlpha ("surface alpha", Range(0,1)) = 0.6
        _fresnelPower ("fresnel power", Range(0.5, 8)) = 3.0

        // Foam (from normal tilt) + ribbons
        _foamStrength ("foam strength (from normal tilt)", Range(0,2)) = 0.8
        _foamColor ("foam color", Color) = (1,1,1,1)
        _RibbonFreq ("foam ribbon freq", Range(0.0, 10.0)) = 2.2
        _RibbonSpeed ("foam ribbon speed", Range(0.0, 8.0)) = 1.2
        _RibbonAmp ("foam ribbon amount", Range(0.0, 1.5)) = 0.6
        _RibbonSharp ("foam ribbon sharpness", Range(0.5, 6.0)) = 2.5
        _RibbonDirXZ ("foam ribbon dir (xz)", Vector) = (1,0,0,0)

        // Vortex (screen-space swirl on refraction)
        _SwirlCenterUV ("vortex center (screen uv)", Vector) = (0.5, 0.5, 0, 0)
        _SwirlStrength ("vortex strength", Range(-4.0, 4.0)) = 1.2
        _SwirlFalloff ("vortex falloff", Range(0.0, 8.0)) = 3.0

        // Wind + Wave bands
        _WindDirXZ ("wind dir (xz)", Vector) = (1,0,0,0)
        _WindFreq ("wind freq", Range(0.0, 20.0)) = 6.0
        _WindSpeed ("wind speed", Range(0.0, 8.0)) = 2.0
        _WindAmp ("wind amp (refraction uv)", Range(0.0, 0.02)) = 0.006

        _BandDirXZ ("band dir (xz)", Vector) = (0,0,1,0)
        _BandFreq ("band freq", Range(0.0, 12.0)) = 3.0
        _BandSpeed ("band speed", Range(0.0, 6.0)) = 0.8
        _BandAmount ("band normal multiplier", Range(0.0, 1.0)) = 0.35
    }

    SubShader 
    {
        Tags 
        { 
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
        }

        // transparency plumbing
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha

        Pass 
        {
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
            float _opacity; // legacy

            float4 _tint;
            float _surfaceAlpha;
            float _fresnelPower;

            float _foamStrength;
            float4 _foamColor;

            float _RibbonFreq;
            float _RibbonSpeed;
            float _RibbonAmp;
            float _RibbonSharp;
            float4 _RibbonDirXZ;

            float4 _SwirlCenterUV;
            float _SwirlStrength;
            float _SwirlFalloff;

            float4 _WindDirXZ;
            float _WindFreq;
            float _WindSpeed;
            float _WindAmp;

            float4 _BandDirXZ;
            float _BandFreq;
            float _BandSpeed;
            float _BandAmount;

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

            struct MeshData 
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators 
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float3 tangent : TEXCOORD2;
                float3 bitangent : TEXCOORD3;
                float3 posWorld : TEXCOORD4;
                float4 uvPan : TEXCOORD5;
                float4 screenUV : TEXCOORD6;
            };

            Interpolators vert (MeshData v) 
            {
                Interpolators o;
                o.uv = TRANSFORM_TEX(v.uv, _albedo);

                // keep your two pan directions
                o.uvPan = float4(float2(0.9, 0.2) * _Time.x, float2(0.5, -0.2) * _Time.x);

                // displacement (kept)
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

            float4 frag (Interpolators i) : SV_Target 
            {
                float2 uv = i.uv;
                float2 screenUV = i.screenUV.xy / i.screenUV.w;

                // --- RNM normal blend (kept) ---
                float3 tN0 = UnpackNormal(_normalMap.Sample(sampler_normalMap, uv + i.uvPan.xy));
                float3 tN1 = UnpackNormal(_normalMap.Sample(sampler_normalMap, (uv * 5) + i.uvPan.zw));
                float3 tN  = BlendNormalRNM(tN0, tN1);
                tN = normalize(lerp(float3(0,0,1), tN, _normalIntensity));

                // --- Wave bands: modulate normal intensity in time/space (world xz) ---
                float2 bandDir = normalize(_BandDirXZ.xz + 1e-5);
                float bandPhase = dot(i.posWorld.xz, bandDir) * _BandFreq + _Time.y * _BandSpeed;
                float bandMask = 0.5 + 0.5 * sin(bandPhase);
                float bandScale = lerp(1.0 - _BandAmount, 1.0 + _BandAmount, bandMask);
                float3 tN_banded = normalize(lerp(float3(0,0,1), tN, saturate(_normalIntensity * bandScale)));

                // --- Foam from normal tilt ---
                float foamCore = saturate(length(tN_banded.xy) * _foamStrength);

                // --- Foam ribbons: sine bands + (very cheap) low-freq albedo channel as noise ---
                float2 ribDir = normalize(_RibbonDirXZ.xz + 1e-5);
                float ribPhase = dot(i.posWorld.xz, ribDir) * _RibbonFreq + _Time.y * _RibbonSpeed;
                float ribSin = 0.5 + 0.5 * sin(ribPhase);
                ribSin = pow(saturate(ribSin), _RibbonSharp);   // sharpen stripes
                float ribMask = saturate(ribSin * _RibbonAmp);

                // optional extra breakup using a low-tiling albedo sample
                float albedoNoise = _albedo.Sample(sampler_albedo, uv * 0.5).r;
                float ribbonedFoam = foamCore * saturate(lerp(1.0, ribMask, 0.8)) * saturate(0.6 + 0.8 * albedoNoise);

                // --- Refraction UV (base) ---
                float2 refractUV = screenUV + (tN_banded.xy * _refractionIntensity);

                // --- Wind: tiny traveling sine along wind dir, applied to refraction only ---
                float2 windDir = normalize(_WindDirXZ.xz + 1e-5);
                float windPhase = dot(i.posWorld.xz, windDir) * _WindFreq + _Time.y * _WindSpeed;
                refractUV += windDir * (sin(windPhase) * _WindAmp);

                // --- Vortex: swirl refractUV around screen-space center with radial falloff ---
                float2 center = _SwirlCenterUV.xy;
                float2 d = refractUV - center;
                float r = length(d);
                if (r > 1e-5)
                {
                    float a = atan2(d.y, d.x);
                    float fall = exp(-_SwirlFalloff * r);                 // stronger near center
                    a += _SwirlStrength * fall;                           // swirl
                    float2 dir = float2(cos(a), sin(a));
                    refractUV = center + r * dir;
                }

                // --- Background sample (refraction) ---
                float3 refractedBG = _CameraOpaqueTexture.Sample(sampler_CameraOpaqueTexture, refractUV);

                // --- TBN (kept) ---
                float3x3 TBN = float3x3(
                    i.tangent.x, i.bitangent.x, i.normal.x,
                    i.tangent.y, i.bitangent.y, i.normal.y,
                    i.tangent.z, i.bitangent.z, i.normal.z
                );
                float3 N = normalize(mul(TBN, tN_banded));

                // --- Lighting (kept) ---
                float3 surfaceColor = _albedo.Sample(sampler_albedo, uv + i.uvPan.xy).rgb * _tint.rgb;
                Light L = GetMainLight();
                float3 V = normalize(GetCameraPositionWS() - i.posWorld);
                float3 H = normalize(V + L.direction);

                float NdotL = max(0, dot(N, L.direction));
                float NdotH = max(0, dot(N, H));

                float3 diffuse  = NdotL * surfaceColor * L.color;
                float3 specular = pow(NdotH, _gloss * MAX_SPECULAR_POWER + 1) * _gloss * L.color;

                // --- Fresnel alpha ---
                float fresnel = pow(saturate(1.0 - dot(normalize(V), N)), _fresnelPower);

                // --- Compose ---
                float3 foamTerm = _foamColor.rgb * ribbonedFoam;
                float3 waterLit = diffuse + specular;

                // keep refraction visible; add a bit of lit contribution, then foam highlights
                float3 color = lerp(refractedBG, waterLit, 0.35) + foamTerm * 0.25;

                // alpha from Fresnel + foam + user control
                float alpha = saturate(_surfaceAlpha * lerp(0.2, 1.0, fresnel) + ribbonedFoam * 0.35);

                return float4(color, alpha);
            }
            ENDHLSL
        }
    }
}
