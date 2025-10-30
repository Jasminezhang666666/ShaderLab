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

        _opacity ("opacity (legacy - not used for alpha)", Range(0,1)) = 0.9
        _tint ("tint", Color) = (0.65, 0.9, 1.0, 1)
        _surfaceAlpha ("surface alpha", Range(0,1)) = 0.6
        _fresnelPower ("fresnel power", Range(0.5, 8)) = 3.0

        // Foam + ribbons (kept)
        _foamStrength ("foam strength (from normal tilt)", Range(0,2)) = 0.8
        _foamColor ("foam color", Color) = (1,1,1,1)
        _RibbonFreq ("foam ribbon freq", Range(0.0, 10.0)) = 2.2
        _RibbonSpeed ("foam ribbon speed", Range(0.0, 8.0)) = 1.2
        _RibbonAmp ("foam ribbon amount", Range(0.0, 1.5)) = 0.6
        _RibbonSharp ("foam ribbon sharpness", Range(0.5, 6.0)) = 2.5
        _RibbonDirXZ ("foam ribbon dir (xz)", Vector) = (1,0,0,0)

        // Screen-space refraction swirl (unchanged; optional)
        _SwirlCenterUV ("vortex center (screen uv)", Vector) = (0.5, 0.5, 0, 0)
        _SwirlStrength ("vortex strength", Range(-4.0, 4.0)) = 1.2
        _SwirlFalloff ("vortex falloff", Range(0.0, 8.0)) = 3.0

        // === Vortex disk (everything only inside this UV circle) ===
        _CircleCenterUV ("Vortex Center (UV)", Vector) = (0.5, 0.5, 0, 0)
        _CircleRadiusUV ("Vortex Radius (UV)", Range(0,1)) = 0.45
        _CircleSpinStrength ("UV spin strength", Range(0,4)) = 1.1
        _CircleAngularSpeed ("UV spin speed (rad/s)", Range(-16,16)) = 2.2
        _CircleFalloffPow ("Inner falloff power", Range(0.5,6)) = 2.0
        _CircleBlendFeather ("Edge feather (UV)", Range(0.0,0.2)) = 0.04

        // Cone depth (vertex-only)
        _ConeDepth ("Cone depth (down along normal)", Range(0,1)) = 0.35
        _ConeFalloffPow ("Cone falloff power", Range(0.5,6)) = 2.2
    }

    SubShader 
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "IgnoreProjector"="True" }
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
            float _opacity;

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

            float4 _CircleCenterUV;
            float _CircleRadiusUV;
            float _CircleSpinStrength;
            float _CircleAngularSpeed;
            float _CircleFalloffPow;
            float _CircleBlendFeather;

            float _ConeDepth;
            float _ConeFalloffPow;

            float4 _albedo_ST;
            CBUFFER_END

            TEXTURE2D(_albedo);          SAMPLER(sampler_albedo);
            TEXTURE2D(_normalMap);       SAMPLER(sampler_normalMap);
            TEXTURE2D(_displacementMap); SAMPLER(sampler_displacementMap);
            TEXTURE2D(_CameraOpaqueTexture); SAMPLER(sampler_CameraOpaqueTexture);

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
                float2 uvBase : TEXCOORD0;   // original UV
                float2 uvUse  : TEXCOORD1;   // rotated inside disk
                float  diskMask : TEXCOORD2; // 1 center → 0 outside (soft blend)
                float3 normal : TEXCOORD3;
                float3 tangent : TEXCOORD4;
                float3 bitangent : TEXCOORD5;
                float3 posWorld : TEXCOORD6;
                float4 uvPan : TEXCOORD7;
                float4 screenUV : TEXCOORD8;
                float2 dFromCenter : TEXCOORD9; // for angular ribbons
            };

            float2 rotate2D(float2 v, float a)
            {
                float s = sin(a), c = cos(a);
                return float2(c*v.x - s*v.y, s*v.x + c*v.y);
            }

            Interpolators vert (MeshData v) 
            {
                Interpolators o;
                float2 baseUV = TRANSFORM_TEX(v.uv, _albedo);
                o.uvBase = baseUV;

                // panning (kept)
                o.uvPan = float4(float2(0.9, 0.2) * _Time.x, float2(0.5, -0.2) * _Time.x);

                // displacement (kept)
                float height = _displacementMap.SampleLevel(sampler_displacementMap, baseUV + o.uvPan.xy, 0).r;
                v.vertex.xyz += v.normal * height * _displacementIntensity;

                // vortex disk
                float2 d = baseUV - _CircleCenterUV.xy;
                float  r = length(d);
                float  R = max(_CircleRadiusUV, 1e-4);

                // soft blend for UVs, hard mask for cone power
                float feather = max(_CircleBlendFeather, 1e-5);
                float softMask = smoothstep(0.0, 1.0, saturate(( _CircleRadiusUV - r ) / feather)); // 1 → 0 at edge
                float hardMask = saturate(1.0 - r / R);

                // cone sink
                float cone = pow(hardMask, _ConeFalloffPow);
                v.vertex.xyz -= v.normal * (_ConeDepth * cone);

                // UV rotation around center (actual swirling)
                float theta = _CircleSpinStrength * pow(hardMask, _CircleFalloffPow) * (_CircleAngularSpeed * _Time.y);
                float2 uvRot = _CircleCenterUV.xy + rotate2D(d, theta);

                // blend rotated UV with original outside the disk
                o.uvUse   = lerp(baseUV, uvRot, softMask);
                o.diskMask = softMask;
                o.dFromCenter = d; // pass for angular ribbons

                // TBN & positions
                o.normal   = TransformObjectToWorldNormal(v.normal);
                o.tangent  = TransformObjectToWorldNormal(v.tangent);
                o.bitangent= cross(o.normal, o.tangent) * v.tangent.w;

                o.vertex   = TransformObjectToHClip(v.vertex);
                o.screenUV = ComputeScreenPos(o.vertex);
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);

                return o;
            }

            float4 frag (Interpolators i) : SV_Target 
            {
                float2 uv = i.uvUse; // rotated inside disk
                float2 screenUV = i.screenUV.xy / i.screenUV.w;

                // Normal maps (use uv that rotates inside the disk)
                float3 tN0 = UnpackNormal(_normalMap.Sample(sampler_normalMap, uv + i.uvPan.xy));
                float3 tN1 = UnpackNormal(_normalMap.Sample(sampler_normalMap, (uv * 5) + i.uvPan.zw));
                float3 tN  = BlendNormalRNM(tN0, tN1);
                tN = normalize(lerp(float3(0,0,1), tN, _normalIntensity));

                // === Foam: make ribbons swirl inside the disk ===
                float foamCore = saturate(length(tN.xy) * _foamStrength);

                // world version (original)
                float2 ribDirW = normalize(_RibbonDirXZ.xz + 1e-5);
                float ribPhaseW = dot(i.posWorld.xz, ribDirW) * _RibbonFreq + _Time.y * _RibbonSpeed;

                // vortex angular version (clearly circular)
                float ang = atan2(i.dFromCenter.y, i.dFromCenter.x);
                float ribPhaseV = ang * _RibbonFreq + _Time.y * _RibbonSpeed;

                // blend: inside disk use angular stripes; outside use world stripes
                float ribPhase = lerp(ribPhaseW, ribPhaseV, saturate(i.diskMask));
                float ribWave  = pow(saturate(0.5 + 0.5 * sin(ribPhase)), _RibbonSharp);
                float ribMask  = saturate(ribWave * _RibbonAmp);

                // small breakup from albedo (sample with rotated uv so texture breakup also orbits)
                float albedoNoise = _albedo.Sample(sampler_albedo, uv * 0.5).r;
                float ribbonedFoam = foamCore * saturate(lerp(1.0, ribMask, 0.8)) * saturate(0.6 + 0.8 * albedoNoise);

                // Refraction (kept, no wind)
                float2 refractUV = screenUV + (tN.xy * _refractionIntensity);

                // Optional screen-space swirl (unchanged)
                float2 center = _SwirlCenterUV.xy;
                float2 d = refractUV - center;
                float r = length(d);
                if (r > 1e-5)
                {
                    float a = atan2(d.y, d.x);
                    float fall = exp(-_SwirlFalloff * r);
                    a += _SwirlStrength * fall;
                    float2 dir = float2(cos(a), sin(a));
                    refractUV = center + r * dir;
                }

                // Background sample
                float3 refractedBG = _CameraOpaqueTexture.Sample(sampler_CameraOpaqueTexture, refractUV);

                // Lighting (kept)
                float3x3 TBN = float3x3(
                    i.tangent.x, i.bitangent.x, i.normal.x,
                    i.tangent.y, i.bitangent.y, i.normal.y,
                    i.tangent.z, i.bitangent.z, i.normal.z
                );
                float3 N = normalize(mul(TBN, tN));
                float3 surfaceColor = _albedo.Sample(sampler_albedo, uv + i.uvPan.xy).rgb * _tint.rgb;

                Light L = GetMainLight();
                float3 V = normalize(GetCameraPositionWS() - i.posWorld);
                float3 H = normalize(V + L.direction);

                float NdotL = max(0, dot(N, L.direction));
                float NdotH = max(0, dot(N, H));

                float3 diffuse  = NdotL * surfaceColor * L.color;
                float3 specular = pow(NdotH, _gloss * MAX_SPECULAR_POWER + 1) * _gloss * L.color;

                float fresnel = pow(saturate(1.0 - dot(normalize(V), N)), _fresnelPower);

                // Compose (kept ratios)
                float3 foamTerm = _foamColor.rgb * ribbonedFoam;
                float3 waterLit = diffuse + specular;

                float3 color = lerp(refractedBG, waterLit, 0.35) + foamTerm * 0.30;
                float alpha = saturate(_surfaceAlpha * lerp(0.2, 1.0, fresnel) + ribbonedFoam * 0.35);

                return float4(color, alpha);
            }
            ENDHLSL
        }
    }
}
