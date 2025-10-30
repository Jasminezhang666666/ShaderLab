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

        // Foam and ribbons
        _foamStrength ("foam strength (from normal tilt)", Range(0,2)) = 0.8
        _foamColor ("foam color", Color) = (1,1,1,1)
        _RibbonFreq ("foam ribbon freq", Range(0.0, 10.0)) = 2.2
        _RibbonSpeed ("foam ribbon speed", Range(0.0, 8.0)) = 1.2
        _RibbonAmp ("foam ribbon amount", Range(0.0, 1.5)) = 0.6
        _RibbonSharp ("foam ribbon sharpness", Range(0.5, 6.0)) = 2.5
        _RibbonDirXZ ("foam ribbon dir (xz)", Vector) = (1,0,0,0)

        // Vortex disk (UV-space, NOT screen-space)
        _CircleCenterUV ("Vortex Center (UV)", Vector) = (0.5, 0.5, 0, 0)
        _CircleRadiusUV ("Vortex Radius (UV)", Range(0,1)) = 0.45
        _CircleSpinStrength ("UV spin strength", Range(0,4)) = 1.1
        _CircleAngularSpeed ("UV spin speed (rad/s)", Range(-16,16)) = 2.2
        _CircleFalloffPow ("Inner falloff power", Range(0.5,6)) = 2.0
        _CircleBlendFeather ("Edge feather (UV)", Range(0.0,0.2)) = 0.04

        // Cone depth (vertex-only)
        _ConeDepth ("Cone depth (down along normal)", Range(0,1)) = 0.35
        _ConeFalloffPow ("Cone falloff power", Range(0.5,6)) = 2.2

        // Underwater blur controls
        _UnderBlurRadius   ("Underwater blur radius (px)", Range(0.0, 3.0)) = 1.5
        _UnderBlurStrength ("Underwater blur strength", Range(0.0, 1.0)) = 0.8
        _DepthSoftRange    ("Depth soft range (eye-units)", Range(0.01, 5.0)) = 1.0
        _EdgeDither        ("Edge micro jitter", Range(0.0, 1.0)) = 0.25
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
            #pragma multi_compile _ _ADDITIONAL_LIGHTS

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

            // (Screen-space swirl REMOVED)

            float4 _CircleCenterUV;
            float _CircleRadiusUV;
            float _CircleSpinStrength;
            float _CircleAngularSpeed;
            float _CircleFalloffPow;
            float _CircleBlendFeather;

            float _ConeDepth;
            float _ConeFalloffPow;

            float _UnderBlurRadius;
            float _UnderBlurStrength;
            float _DepthSoftRange;
            float _EdgeDither;

            float4 _albedo_ST;
            CBUFFER_END

            TEXTURE2D(_albedo);          SAMPLER(sampler_albedo);
            TEXTURE2D(_normalMap);       SAMPLER(sampler_normalMap);
            TEXTURE2D(_displacementMap); SAMPLER(sampler_displacementMap);

            TEXTURE2D(_CameraOpaqueTexture); SAMPLER(sampler_CameraOpaqueTexture);
            TEXTURE2D(_CameraDepthTexture);  SAMPLER(sampler_CameraDepthTexture);

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
                float2 uvBase : TEXCOORD0;
                float2 uvUse  : TEXCOORD1;
                float  diskMask : TEXCOORD2;

                float3 normal : TEXCOORD3;
                float3 tangent : TEXCOORD4;
                float3 bitangent : TEXCOORD5;

                float3 posWorld : TEXCOORD6;
                float4 uvPan    : TEXCOORD7;

                float4 screenUV : TEXCOORD8;     // clip-space projected UV (xy/w)
                float2 dFromCenter : TEXCOORD9;

                float ndcZ : TEXCOORD10;         // z/w (NDC z)
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

                // UV panning
                o.uvPan = float4(float2(0.9, 0.2) * _Time.x,
                                 float2(0.5, -0.2) * _Time.x);

                // Vertex displacement (waves)
                float height = _displacementMap.SampleLevel(sampler_displacementMap, baseUV + o.uvPan.xy, 0).r;
                v.vertex.xyz += v.normal * height * _displacementIntensity;

                // Vortex disk in UV space
                float2 d = baseUV - _CircleCenterUV.xy;
                float  r = length(d);
                float  R = max(_CircleRadiusUV, 1e-4);

                float feather = max(_CircleBlendFeather, 1e-5);
                float softMask = smoothstep(0.0, 1.0, saturate((_CircleRadiusUV - r) / feather)); // 1 center -> 0 edge
                float hardMask = saturate(1.0 - r / R);

                // Cone sink
                float cone = pow(hardMask, _ConeFalloffPow);
                v.vertex.xyz -= v.normal * (_ConeDepth * cone);

                // UV swirl inside disk (mesh-UV space)
                float theta = _CircleSpinStrength * pow(hardMask, _CircleFalloffPow) * (_CircleAngularSpeed * _Time.y);
                float2 uvRot = _CircleCenterUV.xy + rotate2D(d, theta);

                o.uvUse   = lerp(baseUV, uvRot, softMask);
                o.diskMask = softMask;
                o.dFromCenter = d;

                // Transform/TBN
                o.normal   = TransformObjectToWorldNormal(v.normal);
                o.tangent  = TransformObjectToWorldNormal(v.tangent);
                o.bitangent= cross(o.normal, o.tangent) * v.tangent.w;

                float4 posCS = TransformObjectToHClip(v.vertex);
                o.vertex   = posCS;
                o.screenUV = ComputeScreenPos(posCS);
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);

                // Store NDC z (z/w), later remap to 0..1 device depth
                o.ndcZ = posCS.z / posCS.w;

                return o;
            }

            // Tiny hash for micro jitter
            float hash12(float2 p)
            {
                p = frac(p * float2(123.34, 345.45));
                p += dot(p, p + 34.345);
                return frac(p.x * p.y);
            }

            float4 frag (Interpolators i) : SV_Target
            {
                float2 uv = i.uvUse;
                float2 screenUV = i.screenUV.xy / i.screenUV.w;

                // Tangent-space normal (blended)
                float3 tN0 = UnpackNormal(_normalMap.Sample(sampler_normalMap, uv + i.uvPan.xy));
                float3 tN1 = UnpackNormal(_normalMap.Sample(sampler_normalMap, (uv * 5) + i.uvPan.zw));
                float3 tN  = BlendNormalRNM(tN0, tN1);
                tN = normalize(lerp(float3(0,0,1), tN, _normalIntensity));

                // Foam ribbons (world stripes outside, angular stripes inside the vortex disk)
                float foamCore = saturate(length(tN.xy) * _foamStrength);
                float2 ribDirW = normalize(_RibbonDirXZ.xz + 1e-5);
                float ribPhaseW = dot(i.posWorld.xz, ribDirW) * _RibbonFreq + _Time.y * _RibbonSpeed;

                float ang = atan2(i.dFromCenter.y, i.dFromCenter.x);
                float ribPhaseV = ang * _RibbonFreq + _Time.y * _RibbonSpeed;

                float ribPhase = lerp(ribPhaseW, ribPhaseV, saturate(i.diskMask));
                float ribWave  = pow(saturate(0.5 + 0.5 * sin(ribPhase)), _RibbonSharp);
                float ribMask  = saturate(ribWave * _RibbonAmp);

                float albedoNoise = _albedo.Sample(sampler_albedo, uv * 0.5).r;
                float ribbonedFoam = foamCore * saturate(lerp(1.0, ribMask, 0.8)) * saturate(0.6 + 0.8 * albedoNoise);

                // Refraction UV + micro jitter
                float2 px = 1.0 / _ScreenParams.xy;
                float2 jitter = (_EdgeDither * (hash12(screenUV * _ScreenParams.xy) - 0.5)) * px;
                float2 refractUV = screenUV + (tN.xy * _refractionIntensity) + jitter;

                // Safe clamp so sampling never goes outside screen
                float2 uvClampMin = 1.5 * px;
                float2 uvClampMax = 1.0 - uvClampMin;
                refractUV = clamp(refractUV, uvClampMin, uvClampMax);

                // Depth-aware UNDERWATER blur
                float surfaceDepth01 = UNITY_Z_0_FAR_FROM_CLIPSPACE(i.ndcZ);
                float surfaceEyeDepth = LinearEyeDepth(surfaceDepth01, _ZBufferParams);

                float sceneDepth01 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, refractUV);
                bool invalidDepth = (sceneDepth01 <= 0.0001 || sceneDepth01 >= 0.9999);
                float sceneEyeDepth = invalidDepth ? surfaceEyeDepth : LinearEyeDepth(sceneDepth01, _ZBufferParams);

                float depthDelta = max(0.0, sceneEyeDepth - surfaceEyeDepth);
                float underMask  = saturate(depthDelta / max(1e-4, _DepthSoftRange));

                float3 centerBG = _CameraOpaqueTexture.Sample(sampler_CameraOpaqueTexture, refractUV).rgb;

                float rpx = _UnderBlurRadius * underMask;
                float3 acc = centerBG;
                acc += _CameraOpaqueTexture.Sample(sampler_CameraOpaqueTexture, refractUV + float2( rpx, 0)*px).rgb;
                acc += _CameraOpaqueTexture.Sample(sampler_CameraOpaqueTexture, refractUV + float2(-rpx, 0)*px).rgb;
                acc += _CameraOpaqueTexture.Sample(sampler_CameraOpaqueTexture, refractUV + float2( 0, rpx)*px).rgb;
                acc += _CameraOpaqueTexture.Sample(sampler_CameraOpaqueTexture, refractUV + float2( 0,-rpx)*px).rgb;
                float3 blurredBG = acc / 5.0;

                // Fade blur near screen edges to avoid darkening
                float edge = saturate(min(min(refractUV.x, refractUV.y), min(1.0 - refractUV.x, 1.0 - refractUV.y)) * 500.0);
                float blurAmt = _UnderBlurStrength * underMask * edge;
                float3 refractedBG = lerp(centerBG, blurredBG, blurAmt);

                // Lighting (scene lights)
                float3x3 TBN = float3x3(
                    i.tangent.x, i.bitangent.x, i.normal.x,
                    i.tangent.y, i.bitangent.y, i.normal.y,
                    i.tangent.z, i.bitangent.z, i.normal.z
                );
                float3 N = normalize(mul(TBN, tN));
                float3 V = normalize(GetCameraPositionWS() - i.posWorld);

                float3 surfaceColor = _albedo.Sample(sampler_albedo, uv + i.uvPan.xy).rgb * _tint.rgb;

                Light mainL = GetMainLight();
                float3 Ld = mainL.direction;
                float3 Lc = mainL.color;

                float NdotL = max(0, dot(N, Ld));
                float3 H = normalize(V + Ld);
                float NdotH = max(0, dot(N, H));

                float3 diffuse  = NdotL * surfaceColor * Lc;
                float3 specular = pow(NdotH, _gloss * MAX_SPECULAR_POWER + 1) * _gloss * Lc;

                #if defined(_ADDITIONAL_LIGHTS)
                {
                    uint count = GetAdditionalLightsCount();
                    for (uint li = 0u; li < count; li++)
                    {
                        Light add = GetAdditionalLight(li, i.posWorld);
                        float3 Ld2 = normalize(add.direction);
                        float3 Lc2 = add.color;

                        float NdotL2 = max(0, dot(N, Ld2));
                        float3 H2 = normalize(V + Ld2);
                        float NdotH2 = max(0, dot(N, H2));

                        diffuse  += NdotL2 * surfaceColor * Lc2;
                        specular += pow(NdotH2, _gloss * MAX_SPECULAR_POWER + 1) * _gloss * Lc2;
                    }
                }
                #endif

                float3 waterLit = diffuse + specular;
                float fresnel = pow(saturate(1.0 - dot(normalize(V), N)), _fresnelPower);

                // Compose
                float3 foamTerm = _foamColor.rgb * ribbonedFoam;
                float3 color = lerp(refractedBG, waterLit, 0.35) + foamTerm * 0.30;

                // Slightly tighten alpha where object is underwater
                float edgeTighten = saturate(0.25 + 0.75 * underMask);
                float alpha = saturate(_surfaceAlpha * lerp(0.2, 1.0, fresnel) * edgeTighten + ribbonedFoam * 0.35);

                return float4(color, alpha);
            }
            ENDHLSL
        }
    }
}
