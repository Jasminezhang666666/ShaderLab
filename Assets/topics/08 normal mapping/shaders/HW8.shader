// Water surface with UV-space vortex + timed hollow ring fountain
// - Refraction via normal-offset sampling of _CameraOpaqueTexture
// - Foam from normal tilt + ribbon patterns, boosted during fountain phases
// - Vortex: UV spin + conical sink in mesh UV space
// - Fountain: hollow ring column (rise/hold/fade) then splash with petals/ring
Shader "shader lab/week 8/HW8_water_clean"
{
    Properties
    {
        // ===== Surface inputs & core look =====
        _albedo ("albedo", 2D) = "white" {}
        [NoScaleOffset] _normalMap ("normal map", 2D) = "bump" {}
        [NoScaleOffset] _displacementMap ("displacement map", 2D) = "white" {}

        _tint ("tint", Color) = (0.65, 0.9, 1.0, 1)
        _surfaceAlpha ("surface alpha", Range(0,1)) = 0.6
        _fresnelPower ("fresnel power", Range(0.5, 8)) = 3.0

        _gloss ("gloss", Range(0,1)) = 1
        _normalIntensity ("normal intensity", Range(0, 1)) = 1
        _displacementIntensity ("displacement intensity", Range(0,1)) = 0.5
        _refractionIntensity ("refraction intensity", Range(0, 0.5)) = 0.12

        // ===== Foam ribbons (artist-facing) =====
        _foamStrength ("foam from normal tilt", Range(0,2)) = 0.8
        _foamColor ("foam color", Color) = (1,1,1,1)
        _RibbonFreq ("foam ribbon freq", Range(0.0, 10.0)) = 2.2
        _RibbonSpeed ("foam ribbon speed", Range(0.0, 8.0)) = 1.2
        _RibbonAmp ("foam ribbon amount", Range(0.0, 1.5)) = 0.6
        _RibbonSharp ("foam ribbon sharpness", Range(0.5, 6.0)) = 2.5

        // ===== Vortex (UV-space) =====
        _CircleCenterUV ("Vortex Center (UV)", Vector) = (0.25, 0.5, 0, 0)
        _CircleRadiusUV ("Vortex Radius (UV)", Range(0,1)) = 0.35
        _CircleAngularSpeed ("Vortex speed (rad/s)", Range(-16,16)) = 2.2
        _CircleSpinStrength ("Vortex spin strength", Range(0,4)) = 1.1
        _VortexTimeOffset ("Vortex time offset (s)", Range(0, 100)) = 0.0

        // Vortex depth shape (usually fixed once)
        _ConeDepth ("Vortex cone depth", Range(0,1)) = 0.20
        [HideInInspector] _ConeFalloffPow ("Vortex cone falloff", Range(0.5,6)) = 2.2
        [HideInInspector] _CircleBlendFeather ("Vortex edge feather (UV)", Range(0.0,0.2)) = 0.04
        [HideInInspector] _CircleFalloffPow ("Vortex spin falloff", Range(0.5,6)) = 2.0

        // ===== Ring fountain (hollow tube jet) =====
        _RingJetOn           ("RingJet on (0/1)", Range(0,1)) = 1
        _RingJetCenterUV     ("RingJet Center (UV)", Vector) = (0.78, 0.62, 0, 0)
        _RingJetRadiusUV     ("Ring radius (UV)", Range(0.01, 0.25)) = 0.07
        _RingJetThicknessUV  ("Ring thickness (UV)", Range(0.002, 0.12)) = 0.03
        _RingJetHeight       ("Ring body height", Range(0.0, 2.0)) = 0.65

        // Fountain timing (rise -> hold -> fade -> splash)
        _RJ_RiseDur          ("Rise (s)",   Range(0.05, 4.0)) = 0.5
        _RJ_HoldDur          ("Hold (s)",   Range(0.00, 4.0)) = 0.5
        _RJ_VanishDur        ("Vanish (s)", Range(0.05, 4.0)) = 0.5
        _RJ_SplashDur        ("Splash (s)", Range(0.10, 6.0)) = 1.8
        _RJ_TimeOffset       ("RingJet time offset (s)", Range(0,100)) = 0.0

        // Splash look (compact set)
        _RJ_SpokeCount       ("Splash spokes", Range(1,16)) = 12
        _RJ_SpokeSpeed       ("Spoke speed (UV/s)", Range(0.05, 1.2)) = 0.28
        _RJ_SpokeMaxRange    ("Spoke max range (UV)", Range(0.01, 0.40)) = 0.16
        _RJ_RingSpeed        ("Splash ring speed (UV/s)", Range(0.0, 1.0)) = 0.22
        _RJ_RingWidth        ("Splash ring width (UV)",   Range(0.002, 0.10)) = 0.03
        _RJ_Depress          ("Splash depress amount",    Range(0.0, 0.12)) = 0.03
        _RJ_FoamBoost        ("Fountain foam boost", Range(0.0, 3.0)) = 1.25

        // ===== Hidden micro-tweaks =====
        [HideInInspector] _opacity ("opacity (legacy)", Range(0,1)) = 0.9
        [HideInInspector] _RibbonDirXZ ("foam ribbon dir (xz)", Vector) = (1,0,0,0)
        [HideInInspector] _RJ_Smooth ("Phase smooth feather", Range(0.0, 0.3)) = 0.08
        [HideInInspector] _RJ_AlphaTight ("Splash alpha tighten", Range(0.0, 1.0))  = 0.35
        [HideInInspector] _RJ_SpokeWidthUV ("Spoke radial width (UV)", Range(0.002, 0.08)) = 0.025
        [HideInInspector] _RJ_SpokeAngular ("Spoke ang width", Range(0.02, 0.60)) = 0.20
        [HideInInspector] _RJ_Jitter ("Spoke angle jitter", Range(0.0, 1.0)) = 0.35
        [HideInInspector] _EdgeDither ("Edge micro jitter", Range(0.0, 1.0)) = 0.25
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
            #define PI 3.14159265359


            CBUFFER_START(UnityPerMaterial)
            float _gloss, _normalIntensity, _displacementIntensity, _refractionIntensity, _opacity;
            float4 _tint; float _surfaceAlpha, _fresnelPower;

            float _foamStrength; float4 _foamColor;
            float _RibbonFreq, _RibbonSpeed, _RibbonAmp, _RibbonSharp; float4 _RibbonDirXZ;

            float4 _CircleCenterUV; float _CircleRadiusUV, _CircleSpinStrength, _CircleAngularSpeed, _CircleFalloffPow, _CircleBlendFeather;
            float _VortexTimeOffset;
            float _ConeDepth, _ConeFalloffPow;

            float _RingJetOn; float4 _RingJetCenterUV; float _RingJetRadiusUV, _RingJetThicknessUV, _RingJetHeight;
            float _RJ_RiseDur, _RJ_HoldDur, _RJ_VanishDur, _RJ_SplashDur, _RJ_TimeOffset, _RJ_Smooth;
            float _RJ_RingSpeed, _RJ_RingWidth, _RJ_Depress, _RJ_AlphaTight;
            float _RJ_SpokeCount, _RJ_SpokeSpeed, _RJ_SpokeMaxRange, _RJ_SpokeWidthUV, _RJ_SpokeAngular, _RJ_Jitter, _RJ_FoamBoost;

            float _EdgeDither;

            float4 _albedo_ST;
            CBUFFER_END

            // ===== Textures =====
            TEXTURE2D(_albedo);          SAMPLER(sampler_albedo);
            TEXTURE2D(_normalMap);       SAMPLER(sampler_normalMap);
            TEXTURE2D(_displacementMap); SAMPLER(sampler_displacementMap);
            TEXTURE2D(_CameraOpaqueTexture); SAMPLER(sampler_CameraOpaqueTexture);

            // ===== I/O structs =====
            struct MeshData { float4 vertex:POSITION; float3 normal:NORMAL; float4 tangent:TANGENT; float2 uv:TEXCOORD0; };
            struct Interpolators
            {
                float4 vertex:SV_POSITION;

                float2 uvBase:TEXCOORD0;      // original mesh UV
                float2 uvUse:TEXCOORD1;       // UV after vortex rotation
                float  diskMask:TEXCOORD2;    // 0..1 mask within vortex disk

                float3 normal:TEXCOORD3;
                float3 tangent:TEXCOORD4;
                float3 bitangent:TEXCOORD5;

                float3 posWorld:TEXCOORD6;
                float4 uvPan:TEXCOORD7;

                float4 screenUV:TEXCOORD8;    // clip-space projected UV
                float2 dFromVortex:TEXCOORD9; // vector from vortex center in UV

                float bodyFoam:TEXCOORD10;    // boosted foam during jet/splash
                float splashTight:TEXCOORD11; // alpha tighten on splash ring
            };

            // ===== Helpers =====
            float2 rotate2D(float2 v, float a){ float s=sin(a), c=cos(a); return float2(c*v.x - s*v.y, s*v.x + c*v.y); }
            float hash12(float2 p){ p = frac(p*float2(123.34, 345.45)); p += dot(p, p+34.345); return frac(p.x*p.y); }
            float gauss01(float x, float w){ return exp(-abs(x)/max(1e-4,w)); }

            // Phase scheduler for the ring jet
            void RingJetPhases(out float appear, out float splash, out float tInSplash)
            {
                float Tr = max(0.001, _RJ_RiseDur);
                float Th = max(0.0,   _RJ_HoldDur);
                float Tv = max(0.001, _RJ_VanishDur);
                float Ts = max(0.001, _RJ_SplashDur);
                float T  = Tr + Th + Tv + Ts;

                float t  = fmod(_Time.y + _RJ_TimeOffset, T);

                float t1 = Tr;
                float t2 = Tr + Th;
                float t3 = Tr + Th + Tv;

                if (t < t1)       appear = smoothstep(0.0, max(1e-4, t1), t);
                else if (t < t2)  appear = 1.0;
                else if (t < t3)  appear = 1.0 - smoothstep(0.0, 1.0, (t - t2) / max(1e-4, (t3 - t2)));
                else              appear = 0.0;

                if (t >= t3){ splash = smoothstep(0.0, min(0.5, Ts), t - t3); tInSplash = (t - t3); }
                else         { splash = 0.0; tInSplash = 0.0; }
            }

            // Splash field: short radial “petals” + expanding landing ring
            void EvalSplash(
                float2 uv, float2 center, float R0,
                float tSplash, float splashW,
                int N, float spokeSpeed, float spokeMax, float spokeW, float spokeAngW, float jitter,
                float ringSpeed, float ringW,
                out float petals, out float ringMask
            ){
                petals = 0; ringMask = 0;
                if (splashW <= 0.0) return;

                float spokeR = R0 + min(spokeMax, spokeSpeed * tSplash);

                float2 d = uv - center;
                float  r = length(d);
                float  a = atan2(d.y, d.x);

                int kN = max(1, min(16, N));
                float base = 2.0*PI*hash12(center + R0);

                [unroll]
                for(int k=0; k<16; ++k){
                    if(k>=kN) break;
                    float angK = base + (2.0*PI * (k + 0.37*hash12(float2(k, R0))) / (float)kN);
                    angK += (hash12(float2(k, tSplash)) * 2.0 - 1.0) * jitter;

                    float dAng   = acos(saturate(cos(a - angK)));
                    float angMask= exp(-dAng / max(1e-4, spokeAngW));
                    float radMask= exp(-abs(r - spokeR)/max(1e-4, spokeW));
                    petals += angMask * radMask;
                }

                float ringR = R0 + min(spokeMax, ringSpeed * tSplash);
                ringMask = exp(-abs(r - ringR)/max(1e-4, ringW));
            }

            // ===== Vertex stage =====
            Interpolators vert (MeshData v)
            {
                Interpolators o;
                float2 baseUV = TRANSFORM_TEX(v.uv, _albedo);
                o.uvBase = baseUV;

                // Subtle layered UV panning for motion
                o.uvPan = float4(float2(0.9, 0.2)*_Time.x, float2(0.5, -0.2)*_Time.x);

                // Large-scale vertex displacement (waves)
                float h0 = _displacementMap.SampleLevel(sampler_displacementMap, baseUV + o.uvPan.xy, 0).r;
                v.vertex.xyz += v.normal * h0 * _displacementIntensity;

                // Vortex: conical sink + UV rotation
                float2 dv = baseUV - _CircleCenterUV.xy;
                float  rv = length(dv);
                float  Rv = max(_CircleRadiusUV, 1e-4);
                float  feather = max(_CircleBlendFeather, 1e-5);

                float  softMask = smoothstep(0.0, 1.0, saturate((_CircleRadiusUV - rv)/feather));
                float  hardMask = saturate(1.0 - rv/Rv);

                v.vertex.xyz -= v.normal * (_ConeDepth * pow(hardMask, _ConeFalloffPow));

                float theta = _CircleSpinStrength * pow(hardMask, _CircleFalloffPow) * (_CircleAngularSpeed * (_Time.y + _VortexTimeOffset));
                float2 uvRot = _CircleCenterUV.xy + rotate2D(dv, theta);

                o.uvUse    = lerp(baseUV, uvRot, softMask);
                o.diskMask = softMask;
                o.dFromVortex = dv;

                // Ring jet timing and spatial masks
                float appearW, splashW, tSplash;
                RingJetPhases(appearW, splashW, tSplash);

                float2 cRJ = _RingJetCenterUV.xy;
                float  rRJ = _RingJetRadiusUV;
                float  th  = _RingJetThicknessUV;

                float2 dRJ = baseUV - cRJ;
                float  r   = length(dRJ);

                // Hollow tube walls (inner/outer soft boundaries)
                float inner = gauss01((r - (rRJ - th*0.5)), th*0.35);
                float outer = gauss01(((rRJ + th*0.5) - r), th*0.35);
                float bodyMask = saturate(min(inner, outer)) * _RingJetOn;

                // Lift tube during appear phase
                float bodyLift = _RingJetHeight * bodyMask * appearW * _RingJetOn;
                v.vertex.xyz += v.normal * bodyLift;

                // Splash petals/ring for landing effects
                float petalsV, ringMaskV;
                EvalSplash(baseUV, cRJ, rRJ, tSplash, splashW,
                           (int)round(_RJ_SpokeCount), _RJ_SpokeSpeed, _RJ_SpokeMaxRange, _RJ_SpokeWidthUV, _RJ_SpokeAngular, _RJ_Jitter,
                           _RJ_RingSpeed, _RJ_RingWidth,
                           petalsV, ringMaskV);

                // Slight depression where the landing ring hits
                v.vertex.xyz -= v.normal * (_RJ_Depress * ringMaskV * splashW * _RingJetOn);

                // Signals to frag
                o.bodyFoam    = _RJ_FoamBoost * (0.9*bodyMask*appearW + 1.1*petalsV*splashW) * _RingJetOn;
                o.splashTight = saturate(_RJ_AlphaTight * ringMaskV * splashW * _RingJetOn);


                o.normal   = TransformObjectToWorldNormal(v.normal);
                o.tangent  = TransformObjectToWorldNormal(v.tangent.xyz);
                o.bitangent= cross(o.normal, o.tangent) * v.tangent.w;

                float4 posCS = TransformObjectToHClip(v.vertex);
                o.vertex   = posCS;
                o.screenUV = ComputeScreenPos(posCS);
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);

                return o;
            }

            // ===== Fragment stage =====
            float4 frag (Interpolators i) : SV_Target
            {
                float2 uv = i.uvUse;
                float2 screenUV = i.screenUV.xy / i.screenUV.w;

                // Normal-map layering: broad + fine detail
                float3 tN0 = UnpackNormal(_normalMap.Sample(sampler_normalMap, uv + i.uvPan.xy));
                float3 tN1 = UnpackNormal(_normalMap.Sample(sampler_normalMap, (uv*5) + i.uvPan.zw));
                float3 tN  = normalize(lerp(float3(0,0,1), BlendNormalRNM(tN0, tN1), _normalIntensity));

                // Foam: from normal tilt + ribbons (world stripes outside / angular inside vortex)
                float foamCore = saturate(length(tN.xy) * _foamStrength);
                float2 ribDirW = normalize(_RibbonDirXZ.xz + 1e-5);
                float ribPhaseW = dot(i.posWorld.xz, ribDirW) * _RibbonFreq + _Time.y * _RibbonSpeed;

                float ang = atan2(i.dFromVortex.y, i.dFromVortex.x);
                float ribPhaseV = ang * _RibbonFreq + _Time.y * _RibbonSpeed;

                float ribPhase  = lerp(ribPhaseW, ribPhaseV, saturate(i.diskMask));
                float ribWave   = pow(saturate(0.5 + 0.5*sin(ribPhase)), _RibbonSharp);
                float ribMask   = saturate(ribWave * _RibbonAmp);

                float albedoNoise = _albedo.Sample(sampler_albedo, uv*0.5).r;
                float ribbonedFoam = foamCore * saturate(lerp(1.0, ribMask, 0.8)) * saturate(0.6 + 0.8*albedoNoise);

                // Extra foam from fountain body/splash
                ribbonedFoam = saturate(ribbonedFoam + i.bodyFoam);

                // Screen refraction: offset scene color by normal.xy
                float2 px = 1.0/_ScreenParams.xy;
                float jitter = (_EdgeDither * (hash12(screenUV*_ScreenParams.xy) - 0.5));
                float2 refractUV = clamp(screenUV + (tN.xy*_refractionIntensity) + jitter*px, 1.5*px, 1.0-1.5*px);
                float3 refractedBG = _CameraOpaqueTexture.Sample(sampler_CameraOpaqueTexture, refractUV).rgb;

                // Simple lighting (diffuse + glossy)
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

                float3 waterLit = diffuse + specular;

                // Fresnel for edge emphasis & alpha shaping
                float fresnel = pow(saturate(1.0 - dot(normalize(V), N)), _fresnelPower);

                // Final compose
                float3 foamTerm = _foamColor.rgb * ribbonedFoam;
                float3 color = lerp(refractedBG, waterLit, 0.35) + foamTerm * 0.30;

                // Alpha: base transparency * Fresnel, slightly tightened during splash
                float alpha = saturate(_surfaceAlpha * lerp(0.2, 1.0, fresnel) * (1.0 - 0.15*i.splashTight)
                                       + ribbonedFoam * 0.35);

                return float4(color, alpha);
            }
            ENDHLSL
        }
    }
}
