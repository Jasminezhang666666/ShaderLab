Shader "shader lab/week 7/HW7"
{
    Properties
    {
        // Paper tint color.
        _PaperTint      ("Paper Tint", Color) = (0.92,0.95,1.00,1)
        // Fiber luminance texture (R).
        _FiberTex       ("Xuan Fiber (R)", 2D) = "gray" {}
        // Dry grain texture (R).
        _GrainTex       ("Dry Grain (R)", 2D) = "gray" {}

        // Texture scale for paper sampling (affects only paper textures).
        _PaperUVScale   ("Paper UV Scale", Range(4, 20)) = 12

        // >>> NEW: Ink/Effects UV controls (only affect stain/flow/pixel/melt/cracks etc.)
        _InkUVZoom      ("Ink UV Zoom (0.1=zoom-in, 10=zoom-out)", Range(0.1, 10)) = 1.0
        _InkUVOffset    ("Ink UV Offset (x,y)", Vector) = (0,0,0,0)

        // Global time multiplier.
        _MasterSpeed    ("Master Time Scale (slow)", Range(0.1, 2)) = 0.45
        // Overall rip/tear strength.
        _RipStrength    ("Rip/Tear Intensity", Range(0,2)) = 1.3
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }
        Pass
        {
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex   vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // ------------------------------------------------------------
            // Constants kept in code. Small inspector surface.
            #define MAX_DROPS 16
            #define DEG2RAD 0.017453292519943295

            // Ink colors.
            static const float3 INK_BLUE   = float3(0.20, 0.48, 1.00);
            static const float3 INK_YELLOW = float3(1.00, 0.92, 0.18);

            // Stylized lighting.
            static const float  GLOSS=0.75;
            static const float  SPEC_WET_BOOST=1.5;
            static const int    POSTER_STEPS=3;

            // Timeline (seconds).
            static const float  T_BLACK=0.35;
            static const float  T_PIXEL=2.2;
            static const float  T_GLOW =3.4;
            static const float  T_MELT =4.2;
            static const float  T_DRY  =6.0;
            static const float  T_WIND =7.5;

            // Hue shift and emission.
            static const float  HUE_TIME_SCALE=0.32;
            static const float  YELLOW_THR=0.63;
            static const float  EMISS_AMP=2.0;

            // Flow field and spin.
            static const float  FLOW_STRENGTH=1.2;
            static const float  SPIN_INTENS=0.8;
            static const float4 VORTEX0=float4(0.5,0.5,0.25,2.0); // (uvx,uvy,radius,omega)

            // Pixelation.
            static const float  PIXEL_STEP_MIN=0.007;
            static const float  PIXEL_STEP_MAX=0.028;
            static const float  DITHER_POWER  =0.5;

            // Melt and paper parameters.
            static const float  MELT_GRAVITY=0.50;
            static const float  MELT_WET_THR=0.36;
            static const float  EDGE_GAIN=1.4;
            static const float  ABSORB_STRENGTH=0.18;

            // Crack tuning.
            static const float  RIP_HAIR_FREQ   = 34.0; // Line count.
            static const float  RIP_HAIR_WIDTH  = 0.07; // Line width.
            static const float  RIP_HAIR_DEPTH  = 0.55; // Darken amount.
            static const float  RIP_CHUNK_FREQ  = 6.0;  // Piece density.
            static const float  RIP_CHUNK_GAIN  = 1.6;  // Piece growth.
            static const float  RIP_CHUNK_ALPHA = 0.65; // Alpha removal.
            static const float  RIM_CHIP_GAIN   = 1.0;  // Border chipping.

            // ------------------------------------------------------------
            // Material constants.
            CBUFFER_START(UnityPerMaterial)
            float4 _PaperTint;
            float  _PaperUVScale;

            // controls for ink/effects space
            float  _InkUVZoom;
            float4 _InkUVOffset;  

            float  _MasterSpeed;
            float  _RipStrength;
            float  _DropCount;      // Drop count from script.
            CBUFFER_END

            // Drop arrays from script.
            float4 _DropPosTime[MAX_DROPS];  // (ux,uy,baseR,start)
            float4 _DropParamsA[MAX_DROPS];  // (anisoPar, anisoPerp, expand, seed)

            // Textures.
            TEXTURE2D(_FiberTex);  SAMPLER(sampler_FiberTex);
            TEXTURE2D(_GrainTex);  SAMPLER(sampler_GrainTex);

            // ------------------------------------------------------------
            // Mesh I/O.
            struct MeshData
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv     : TEXCOORD0;
                float2 uv2    : TEXCOORD1;   // x=edge mask, y=ridge mask
            };

            struct Interpolators
            {
                float4 posCS   : SV_POSITION;
                float3 normalWS: TEXCOORD0;
                float3 worldPos: TEXCOORD1;
                float2 uv      : TEXCOORD2;
                float2 uvInk   : TEXCOORD3;
            };

            // Wind direction helper.
            float2 WindDirVec()
            {
                float a = 30.0 * DEG2RAD;
                return float2(cos(a), sin(a));
            }

            // Map mesh UV -> ink/effects UV by centered zoom & offset.
            // zoom < 1.0 = zoom in (see more detail), zoom > 1.0 = zoom out.
            float2 ToInkUV(float2 uv)
            {
                float2 off = _InkUVOffset.xy;    // user-specified offset (in uv units)
                float  z   = max(_InkUVZoom, 1e-4);
                return (uv + off - 0.5) / z + 0.5;
            }

            // Simple scroll bend and subtle waving.
            Interpolators vert (MeshData v)
            {
                const float BEND=0.28;   // Bend strength.
                const float FLAG_A=0.03; // Wave amplitude.
                const float FLAG_F=5.7;  // Wave frequency.

                float3 p = v.vertex.xyz;

                // Parabolic roll across X.
                float t = (v.uv.x - 0.5) * 2.0;
                p.z += -0.5 * BEND * t * t;

                // Soft waving based on uv2 edge mask.
                p.y += sin(_Time.y * FLAG_F + v.uv.y * 12.0 + v.uv.x * 5.3) * FLAG_A * v.uv2.x;

                // Small twist along wind.
                float2 W = WindDirVec() * 0.9;
                float along = v.uv.x * W.x + v.uv.y * W.y;
                float tw = sin(along * 6.28318 + _Time.y * 1.3) * 0.05 * v.uv2.y;
                float s = sin(tw), c = cos(tw);
                float2 xy = float2(c*p.x - s*p.y, s*p.x + c*p.y);
                p.x = xy.x; p.y = xy.y;

                Interpolators o;
                float3 posWS = TransformObjectToWorld(p);
                o.posCS    = TransformWorldToHClip(posWS);
                o.worldPos = posWS;
                o.normalWS = TransformObjectToWorldNormal(v.normal);
                o.uv       = v.uv;
                o.uvInk    = ToInkUV(v.uv);
                return o;
            }

            // Noise helpers -----------------------------
            float hash21(float2 p){ return frac(sin(dot(p, float2(12.9898,78.233))) * 43758.5453123); }
            float whiteNoise(float2 p){ return frac(sin(dot(p, float2(128.239,-78.381))) * 437587.5453); }

            float valueNoise(float2 uv)
            {
                float2 ip = floor(uv), f = frac(uv);
                float a = hash21(ip);
                float b = hash21(ip + float2(1,0));
                float c = hash21(ip + float2(0,1));
                float d = hash21(ip + float2(1,1));
                float2 u = smoothstep(0,1,f);
                return lerp(lerp(a,b,u.x), lerp(c,d,u.x), u.y);
            }

            float fbm(float2 uv)
            {
                float f = 1.0, a = 0.5, s = 0.0;
                [unroll] for (int i=0;i<4;i++) { s += a * valueNoise(uv * f); f *= 2.0; a *= 0.5; }
                return s;
            }

            // Fiber tangent from luminance gradient (uses paper UV scale).
            float2 FiberTangent(float2 uvTex)
            {
                float e = 1.0 / max(_PaperUVScale * 256.0, 64.0);
                float2 du = float2(e,0), dv = float2(0,e);
                float fx1 = SAMPLE_TEXTURE2D(_FiberTex, sampler_FiberTex, uvTex + du).r;
                float fx0 = SAMPLE_TEXTURE2D(_FiberTex, sampler_FiberTex, uvTex - du).r;
                float fy1 = SAMPLE_TEXTURE2D(_FiberTex, sampler_FiberTex, uvTex + dv).r;
                float fy0 = SAMPLE_TEXTURE2D(_FiberTex, sampler_FiberTex, uvTex - dv).r;
                float2 grad = float2(fx1 - fx0, fy1 - fy0);
                return normalize(float2(-grad.y, grad.x) + 1e-5);
            }

            // Drop contribution.
            void DropContribution(
                float2 uv, float t, float2 center, float baseR,
                float anisoPar, float anisoPerp, float expandSpeed,
                out float thick, out float wet, out float hueK, out float blackPulse)
            {
                // Absorb amount from fiber luminance (paper sampling stays in paper UV space)
                float paperL = SAMPLE_TEXTURE2D(_FiberTex, sampler_FiberTex, uv * _PaperUVScale).r;
                float absorb = saturate(1.0 + ABSORB_STRENGTH * (paperL - 0.5));
                float R = (baseR + expandSpeed * sqrt(max(t,0))) * absorb;

                // Anisotropic falloff aligned to fiber (fiber tangent also uses paper UV space)
                float2 dirT = FiberTangent(uv * _PaperUVScale);
                float2 dirN = float2(-dirT.y, dirT.x);
                float2 d = uv - center;
                float2 proj = float2(dot(d, dirT), dot(d, dirN));
                float a = max(1e-4, anisoPar*R);
                float b = max(1e-4, anisoPerp*R);
                float fall = exp(- (proj.x*proj.x)/(a*a) - (proj.y*proj.y)/(b*b));

                // Edge-deeper ring
                float ring = saturate(1.0 - smoothstep(0.0, 1.0, length(d)/max(R,1e-4)));
                thick = saturate(0.6*fall + 0.4*ring);

                // Wetness decay
                float wet0 = smoothstep(0, 0.2, fall);
                float dryK = smoothstep(T_DRY, T_DRY+1.2, t);
                wet = saturate(wet0 * (1.0 - 0.85*dryK));

                // Hue progress
                hueK = saturate(smoothstep(0.15, 1.0, t/T_GLOW));

                // Initial black pulse
                blackPulse = (t>=0 && t<=T_BLACK) ? 1.0 : 0.0;
            }

            // Aggregate all drops
            void AccumulateDrops(
                float2 uv, float tNow,
                out float thick, out float wet, out float blackPulse, out float hueK,
                out float wPixel, out float wGlow, out float wMelt, out float wDry, out float wWind,
                out float ripPhaseEarly, out float ripPhaseLate)
            {
                thick=0; wet=0; blackPulse=0; hueK=0;
                wPixel=wGlow=wMelt=wDry=wWind=0;
                ripPhaseEarly=0; ripPhaseLate=0;

                int count = (int)_DropCount;
                [loop] for (int i=0;i<MAX_DROPS;i++)
                {
                    if (i>=count) break;

                    float4 pt = _DropPosTime[i];
                    float4 pa = _DropParamsA[i];
                    float t = tNow - pt.w;
                    if (t < 0) continue;

                    float ti, wi, hk, bp;
                    DropContribution(uv, t, pt.xy, pt.z, pa.x, pa.y, pa.z, ti, wi, hk, bp);

                    thick = max(thick, ti);
                    wet   = max(wet, wi);
                    blackPulse = max(blackPulse, bp);
                    hueK = max(hueK, hk);

                    wPixel = max(wPixel, step(T_PIXEL, t));
                    wGlow  = max(wGlow,  step(T_GLOW,  t));
                    wMelt  = max(wMelt,  step(T_MELT,  t));
                    wDry   = max(wDry,   step(T_DRY,   t));
                    wWind  = max(wWind,  step(T_WIND,  t));

                    // Two-phase rip progress.
                    float pre  = saturate((t - (T_DRY - 0.9)) / 0.9);
                    float late = saturate((t - T_DRY) / max(0.001,(T_WIND - T_DRY + 1.2)));
                    ripPhaseEarly = max(ripPhaseEarly, pre);
                    ripPhaseLate  = max(ripPhaseLate,  late);
                }
            }

            // Small jitter for desynchronization.
            float TinyPhaseJitter(float2 uv)
            {
                return (hash21(uv*float2(817.3,113.7)) - 0.5) * 0.08;
            }

            // Pixelation with white-noise jitter
            float2 pixelizeUV(float2 uv, float thick, float wet)
            {
                float k = saturate(thick*0.7 + (1-wet)*0.3);
                float step = lerp(PIXEL_STEP_MIN, PIXEL_STEP_MAX, k);
                float2 base = floor(uv/step)*step + step*0.5;
                float n = whiteNoise(floor(base*1024.0));
                return base + (n-0.5) * step * DITHER_POWER;
            }

            // Hue blend from blue to yellow.
            float3 hueBlendBlueToYellow(float3 blue, float3 yellow, float NdotL, float wet, float hueK, float tNow, float2 uv)
            {
                float t = tNow * HUE_TIME_SCALE;
                float kL = 0.35*(1.0-NdotL);
                float kW = 0.25*(1.0-wet);
                float kT = 0.15*(0.5+0.5*sin(t + TinyPhaseJitter(uv)));
                float k  = saturate(hueK*0.6 + kL + kW + kT);
                return lerp(blue, yellow, k);
            }

            // Crack masks: hairline and chunk.
            // NOTE: keep paper-aligned behavior by using paper-scaled tangent externally.
            float2 CrackMasks(float2 uv, float2 tan, float early, float late)
            {
                // Projection along fiber tangent.
                float u1D = dot(uv * _PaperUVScale, tan);

                // Hairline ridges.
                float base = u1D * RIP_HAIR_FREQ + fbm(uv*_PaperUVScale*2.5)*1.7;
                float wave = abs(frac(base) - 0.5);
                float hair = smoothstep(RIP_HAIR_WIDTH*1.6, RIP_HAIR_WIDTH, wave);
                hair *= early;

                // Chunk edges via cell distances.
                float2 g = uv * _PaperUVScale * RIP_CHUNK_FREQ;
                float2 ip=floor(g), f=frac(g);
                float dmin=1, d2min=1;
                [unroll] for(int j=-1;j<=1;j++)
                [unroll] for(int i=-1;i<=1;i++)
                {
                    float2 cell=float2(i,j);
                    float2 p=ip+cell;
                    float2 h=float2(hash21(p),hash21(p+7.1))*0.8;
                    float2 q = cell + h - f;
                    float d = dot(q,q);
                    if (d<dmin) { d2min=dmin; dmin=d; }
                    else if (d<d2min) { d2min=d; }
                }
                float edge = saturate((d2min - dmin) * 12.0);
                float chunk = saturate(pow(edge * RIP_CHUNK_GAIN, 1.2)) * late;

                return float2(hair, chunk);
            }

            // Fragment.
            float4 frag(Interpolators i):SV_Target
            {
                float tNow = _Time.y * _MasterSpeed;

                // Lighting setup.
                float3 N = normalize(i.normalWS);
                Light Lm = GetMainLight();
                float3 L = normalize(Lm.direction);
                float3 V = normalize(GetCameraPositionWS() - i.worldPos);
                float3 Hh = normalize(V + L);
                float  NdotL = saturate(dot(N,L));
                float  halfLambert = pow(NdotL*0.5 + 0.5, 2.0);

                // --- Use ink/effects UV for all stain/flow/pixel/melt/crack generation -----
                float2 uvInk = i.uvInk;

                // Drop fields (use ink UV so scale is controllable)
                float thick, wet, blackPulse, hueK;
                float wPixel, wGlow, wMelt, wDry, wWind;
                float ripEarly, ripLate;
                AccumulateDrops(uvInk, tNow, thick, wet, blackPulse, hueK,
                                wPixel, wGlow, wMelt, wDry, wWind, ripEarly, ripLate);

                // Paper-only branch (paper sampling still uses original i.uv with _PaperUVScale)
                if ((int)_DropCount<=0 || (thick<=1e-4 && wet<=1e-4))
                {
                    float fiberOnly = SAMPLE_TEXTURE2D(_FiberTex, sampler_FiberTex, i.uv*_PaperUVScale).r;
                    float3 paperOnly = _PaperTint.rgb * (0.92 + 0.08*fiberOnly);
                    return float4(paperOnly, 1);
                }

                // Paper ambient occlusion factor (paper textures remain unchanged)
                float fiber = SAMPLE_TEXTURE2D(_FiberTex, sampler_FiberTex, i.uv*_PaperUVScale).r;
                float paperAO = 0.7 + 0.3 * fiber;

                // Filament edge from FBM gradient (use ink UV so detail scales with zoom)
                float f0=fbm(uvInk*2.3), f1=fbm(uvInk*2.3+float2(0.003,0)), f2=fbm(uvInk*2.3+float2(0,0.003));
                float edge = abs(f1-f0)+abs(f2-f0);
                float filamentMask = saturate(edge*4.0) * EDGE_GAIN;

                // Flow field and spin (ink UV)
                float2 uvFlow = uvInk;
                float2 F = normalize(float2(
                    - (fbm(uvInk*1.5+float2(0.002,0)) - fbm(uvInk*1.5-float2(0.002,0))),
                    - (fbm(uvInk*1.5+float2(0,0.002)) - fbm(uvInk*1.5-float2(0,0.002)))
                )) * FLOW_STRENGTH;
                uvFlow -= F * lerp(0.006, 0.028, saturate(filamentMask + (1-wMelt)));

                float2 c = VORTEX0.xy; float rad = VORTEX0.z; float omg = VORTEX0.w;
                float  fall = smoothstep(1,0,distance(uvInk,c)/rad);
                float  ang  = omg * tNow;
                float2 d    = uvInk - c;
                float  s = sin(ang*fall), co = cos(ang*fall);
                float2 uvSpin = c + float2(co*d.x - s*d.y, s*d.x + co*d.y);
                float2 uvAfter = lerp(uvFlow, uvSpin, SPIN_INTENS * filamentMask);

                // Pixelation phase (ink UV)
                float2 uvPix = (wPixel>0.0) ? pixelizeUV(uvAfter, thick, wet) : uvAfter;

                // Melt downward (ink UV)
                float meltGate = max(step(MELT_WET_THR, wet), wMelt);
                uvPix.y += meltGate * lerp(0.4, 1.0, wMelt) * MELT_GRAVITY * frac(tNow);

                // Ink base color (pass ink UV for tiny phase jitter)
                float3 inkBase = hueBlendBlueToYellow(INK_BLUE, INK_YELLOW, NdotL, wet, hueK, tNow, uvInk);
                float3 inkCol  = lerp(inkBase, float3(0,0,0), blackPulse);

                // Diffuse and specular
                float  lamP = ceil(halfLambert*POSTER_STEPS) / POSTER_STEPS;
                float3 diff = lamP * inkCol * Lm.color * paperAO;
                float  spec = pow(saturate(dot(N,Hh)), lerp(8,256,GLOSS)) * GLOSS * (0.3+0.7*wet) * SPEC_WET_BOOST;
                float3 spe  = spec * Lm.color;

                // Emission (based on color progression; jitter uses ink UV)
                float yellowGate = smoothstep(YELLOW_THR + TinyPhaseJitter(uvInk)*0.05, 1.0, dot(inkBase, float3(0.333,0.333,0.333)));
                float eCurve = saturate(yellowGate*(0.3+0.7*thick)*(0.2+0.8*(1.0-wet)));
                float3 emis = inkBase * eCurve * (EMISS_AMP * lerp(0.5,1.5,wGlow));

                // Dry grain modulation (paper texture unaffected)
                float dryMask = saturate(1.0 - wet*1.2);
                float grain = SAMPLE_TEXTURE2D(_GrainTex, sampler_GrainTex, i.uv*6.0).r;
                float3 dryDetail = lerp(1.0, 0.75 + 0.25*grain, max(dryMask, wDry));

                float3 color = (diff + spe) * dryDetail;
                color = lerp(color, color + emis, yellowGate);

                // Cracks: tangent from paper fibers (stable), positions from ink UV (so scale follows zoom)
                float2 tan = FiberTangent(i.uv);  // keep fiber alignment on real paper
                float2 hc  = CrackMasks(uvInk, tan, ripEarly, ripLate);
                float hair  = hc.x;
                float chunk = hc.y;

                // Darken along hairline
                color *= (1.0 - hair * RIP_HAIR_DEPTH);

                // Chunk removal to paper color
                float3 paperCol = _PaperTint.rgb * (0.92 + 0.08 * fiber);
                color = lerp(color, paperCol, chunk * RIP_CHUNK_ALPHA * _RipStrength);

                float alpha = 1.0 - chunk * RIP_CHUNK_ALPHA * _RipStrength;

                // Rim chipping (uses screen-edge in original UV)
                float rim = 1.0 - min(min(i.uv.x,1-i.uv.x), min(i.uv.y,1-i.uv.y))*2.0;
                float rimChip = saturate(rim) * RIM_CHIP_GAIN * ripLate;
                color = lerp(color, paperCol, rimChip * 0.35);
                alpha = max(0.0, alpha - rimChip * 0.25);

                // Late-stage contrast boost
                float late = saturate(0.5*wDry + 1.0*wWind + 0.5*ripLate);
                float3 fromPaper = color - paperCol;
                float pepper = (hash21(uvInk*float2(193.7,271.1)) - 0.5) * 0.08;
                color = paperCol + fromPaper * (1.0 + late * (0.70 + pepper));

                // Final tint mix
                color *= lerp(float3(1,1,1), _PaperTint.rgb, 0.72);

                return float4(saturate(color), saturate(alpha));
            }
            ENDHLSL
        }
    }
}
