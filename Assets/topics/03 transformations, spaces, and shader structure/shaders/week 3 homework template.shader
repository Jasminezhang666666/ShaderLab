Shader "shader lab/week 3/homework template" {
    Properties {
        _hour   ("hour",   Float) = 0
        _minute ("minute", Float) = 0
        _second ("second", Float) = 0
    }

    SubShader {
        Tags { "RenderPipelien" = "UniversalPipeline" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #define TAU 6.283185307

            CBUFFER_START(UnityPerMaterial)
            float _hour;
            float _minute;
            float _second;
            CBUFFER_END

            struct MeshData {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }

            // ------------------ helpers ------------------
            // filled circle (radius r, AA thickness t)
            float circleAA(float2 p, float r, float t){
                float d = length(p) - r;
                return 1.0 - smoothstep(-t, t, d);
            }

            // ring (center radius r, half-thickness th, AA t)
            float ringAA(float2 p, float r, float th, float t){
                float d = abs(length(p) - r) - th;
                return 1.0 - smoothstep(-t, t, d);
            }

            // Angle helpers: top (12 o'clock) maps to 0..1 increasing clockwise
            float ang01_raw(float2 p){ return (atan2(p.y, p.x)/TAU) + 0.5; } //Right=0.5, Up=0.75, Left≈0 (1.0 wraps), Down=0.25
            float angTop01(float2 p){ return frac(ang01_raw(p)+0.25); } //add 0.25 turns (i.e., 90°) and wrap to 0..1. That rotates the reference so top (up) becomes 0.
            float angDist01(float a, float b){ return 0.5 - abs(frac(a-b+0.5)-0.5); } //shortest angular distance (in turns)

            // Leaf mask along angular direction aT (0..1, 12 o'clock = 0, clockwise)
            // From radius r0 to r1, max half-width wMax (AA = aa). Pointy ends, widest in the middle.
            float leafMask(float2 p, float aT, float r0, float r1, float wMax, float aa)
            {
                float theta = aT * TAU;
                float2 d = float2(sin(theta), cos(theta));   // along-hand axis (up); Build a unit direction vector for the leaf’s axis.
                float2 n = float2(cos(theta), -sin(theta));  // normal axis (right), n is perpendicular to d
                float y = dot(p, d); //position along the leaf (how far from center along direction d)
                float x = dot(p, n); //position across the leaf (left/right from the centerline).
                //Gate the shape to only exist between r0 and r1 along y:
                float inner = smoothstep(r0 - aa, r0, y); //ramps from 0→1 as y crosses r0 (soft start).
                float outer = 1.0 - smoothstep(r1, r1 + aa, y); //ramps from 1→0 as y crosses r1 (soft end)

                float t = saturate((y - r0) / max(1e-5, (r1 - r0))); //Normalize the along-axis coordinate to 0..1 over the leaf length: t=0 at r0 (base), t=1 at r1 (tip).
                float halfW = wMax * sin(3.14159265 * t);     // sin(pi*t): 0→peak→0

                float wing = 1.0 - smoothstep(0.0, aa, abs(x) - halfW);
                return saturate(wing * inner * outer);
            }

            // Simple 1D hash
            float hash11(float x){ return frac(sin(x*127.1)*43758.5453); }

            // Gaussian ring falloff: x = |r - R|, width = w      r (pixel radius) R (ring center radius)
            //how far from the ring center
            float ringGauss(float x, float w){
                float t = x / max(1e-5, w);
                return exp(-t*t);
            }

            // ------------------ fragment ------------------
            float4 frag (Interpolators i) : SV_Target
            {
                float2 uv = i.uv * 2 - 1;
                float aa = max(fwidth(uv.x), fwidth(uv.y)) * 1.5; //a per-pixel edge thickness derived from derivatives (fwidth)

                // Palette
                float3 colWaterDeep  = float3(0.05, 0.11, 0.24);
                float3 colWaterLight = float3(0.18, 0.45, 0.78);
                float3 colLotusPink  = float3(0.97, 0.65, 0.80);
                float3 colPodRim     = float3(0.39, 0.57, 0.38);
                float3 colSeed       = float3(0.96, 0.96, 0.94);
                float3 dotRimDarkGreen = float3(0.03, 0.10, 0.06); // very dark green seed rims
                float3 colDeepGreen  = float3(0.22, 0.55, 0.36); // second hand (filled)
                float3 colLightGreen = float3(0.74, 0.91, 0.76); // minute hand (filled)
                float3 colGold       = float3(0.96, 0.82, 0.35); // hour hand stroke
                float3 colRippleBlue = float3(0.34, 0.65, 0.95);

                // Sizes
                float rDial  = 0.85;
                float rDots  = 0.62;
                float dotR   = 0.045;

                // Background water gradient + vignette
                float rr   = length(uv);
                float3 water = lerp(colWaterLight, colWaterDeep, smoothstep(0.0, 1.0, rr)); //from light→deep blue
                float vign = 1.0 - smoothstep(0.75, 0.98, rr);
                water *= lerp(0.85, 1.0, vign); //Subtle vignette multiplies brightness near the edges (slightly darker perimeter)

                // Center pod: scalloped rim, creamy fill, slow CCW rotation
                float podRot = TAU * frac(_second / 60.0);     // 1 turn per minute
                float podAng = atan2(uv.y, uv.x) - podRot;     // CCW

                float rPodBase = 0.46;
                float rPodAmp  = 0.012; //amplitude
                float rPodTh   = 0.030;
                float podN     = 18.0; //how many bumps ("scallops") around the circle

                float rPodVar  = rPodBase + cos(podAng * podN) * rPodAmp; //A cosine in angle modulates the pod radius → rounded “beads” around the edge
                float podRimM  = 1.0 - smoothstep(-1.5*aa, 1.5*aa, abs(length(uv) - rPodVar) - rPodTh);

                float3 col = water;
                col = lerp(col, colPodRim * 0.85, podRimM);

                // Creamy inner fill
                float innerR   = rPodBase - 0.5*rPodTh;
                float podFillM = circleAA(uv, innerR, 1.5*aa);
                float3 podFillCol = float3(0.96, 0.98, 0.97);
                col = lerp(col, podFillCol, podFillM);


                // Thin gold inner rim
                float innerRim = ringAA(uv, innerR, 0.004, 1.5*aa);
                col = lerp(col, colGold*0.9 + colPodRim*0.1, innerRim);

                // inner ring
                col = lerp(col, colPodRim * 0.9, ringAA(uv, 0.30, 0.006, 1.5*aa));

                // Juicy seed pop when the second hand lands: one dot every 5 seconds
                float t5   = frac(_second / 5.0);                  // 0..1 within current 5s slot
                float idxF = floor(_second / 5.0);                 // target seed index (0..11)
                float impulse = (8.0 * t5) * exp(1.0 - 8.0 * t5);  // quick pop then settle
                float pulseAmt = 0.35 * impulse;                   // up to +35% radius

                // 12 seeds around the ring (with dark-green rims)
                for (int k=0; k<12; k++)
                {
                    float a  = (k/12.0)*TAU; //Place 12 seeds evenly on a circle of radius rDots
                    float2 c = float2(sin(a), cos(a)) * rDots; //Using (sin, cos) means k=0 is at the top (12 o’clock): (0,1)*rDots

                    float eqMask = 1.0 - saturate(abs((float)k - idxF)); // 1 if active seed: If k == idxF, then abs(...) = 0 → saturate(0)=0 → eqMask=1. otherwise eqMask=0
                    float scale  = 1.0 + pulseAmt * eqMask; //Only the active seed gets scaled up (up to 1.35×

                    float d    = circleAA(uv - c, dotR * scale, 1.5*aa); //Draw the filled seed
                    float ring = ringAA  (uv - c, (dotR+0.014) * scale, 0.008 * scale, 1.5*aa); //Draw a rim that scales with seed (thickness stays proportional)

                    col = lerp(col, colSeed, d);
                    col = lerp(col, dotRimDarkGreen, ring);
                }


                // Pink lotus "snake": alternates inside/outside between seeds, moves clockwise
                float rTrack = rDots; //base r of the path (same ring as the 12 seeds)
                float gap    = 0.013; //seed radius
                float extra  = 0.025; //safety offset so the snake doesn’t touch the seed
                float amp    = dotR + gap + extra;

                //The head angle (clockwise) and arc length
                float head  = 1.0 - frac(_second/60.0); // _second/60 advances one full turn per minute, 1.0 - frac(…) flips to clockwise.
                float len01 = 1.0/5.0; //the snake’s visible arc spans ~72°

                float aTopRaw = angTop01(uv); // pixel’s angle (turns), top=0, CW positive
                float aDist   = angDist01(aTopRaw, head); //how far (in turns) this pixel is from the head along the circle.
                float along   = 1.0 - smoothstep(len01, len01+0.01, aDist); //a soft angular band mask—1 near the head, fades to 0 after ~len01 turns

                // Make the zig-zag (inside/outside) switch between seeds
                float aTopShift = frac(aTopRaw + (1.0/24.0)); // shift seam by half a sector
                float idx   = floor(aTopShift * 12.0); //Which sector (0..11) am I in? Multiply by 12 to map [0,1) → [0,12), then floor to get an integer index.
                float dir   = (fmod(idx, 2.0) > 0.5) ? +1.0 : -1.0; // alternate +/− each sector
                float local = frac(aTopShift * 12.0); //the progress inside the current sector (0 at boundary, 0.5 at the seed, 1 at the next boundary).

                float tri   = 1.0 - abs(local - 0.5) * 2.0; // triangle wave: 0 at edges, 1 at center
                float wave  = pow(saturate(tri), 1.25); //often/shape the peak

                float rSeg  = rTrack + dir * amp * wave; //the target radius for this pixel’s angle: base radius plus inside/outside offset
                float tube  = ringAA(uv, rSeg, 0.010, 1.5*aa); //draws a deformed ring—a tubular band whose centerline wiggles in and out as angle changes
                float snake = saturate(along * tube); //Multiply by along so we only keep the part under the moving arc near the head.

                col = lerp(col, colLotusPink, snake);


                // Dragonfly leaf hands (second/minute filled, hour stroked)
                float aHour = frac((_hour/12.0) + (_minute/60.0)/12.0); //maps 0..12 hours → 0..1 turns.
                float minuteIndex = floor(_minute + 1e-4); //gives an integer minute that does not change within the minute
                float aMinute = frac(1.0 - (minuteIndex / 60.0)); //the minute hand stays still during the minute and jumps CCW by 1/60 turn at each new minute
                float aSecond = frac(_second/60.0);

                //Generate leaf-shaped masks for each hand
                float mSec = leafMask(uv, aSecond, 0.010, 0.86, 0.016, aa);
                col = lerp(col, colDeepGreen, mSec);

                float mMin = leafMask(uv, aMinute, 0.015, 0.78, 0.022, aa);
                col = lerp(col, colLightGreen, mMin);

                //Draw the hour hand as a gold outline
                float mHourOuter = leafMask(uv, aHour, 0.020, 0.55, 0.030, aa);
                float mHourInner = leafMask(uv, aHour, 0.024, 0.51, 0.024, aa);

                float mHourOuter2 = leafMask(uv, aHour, 0.010, 0.38, 0.020, aa);
                float mHourInner2 = leafMask(uv, aHour, 0.018, 0.25, 0.014, aa);


                float mHourStroke = saturate(mHourOuter - mHourInner);
                float mHourStroke2 = saturate(mHourOuter2 - mHourInner2);

                col = lerp(col, colGold, mHourStroke);
                col = lerp(col, colGold, mHourStroke2);


                /*
                // --- Single wavy rim ripple ---
                
                float rimT     = _Time.y;                      // time for motion
                float rimAng   = atan2(uv.y, uv.x);            // polar angle
                float rimBase  = rDial + 0.018;                // base radius just outside the dial
                float rimAmp   = 0.010;                        // radial wobble amplitude
                float rimFreq1 = 10.0;                         // low-frequency lobes
                float rimFreq2 = 17.0;                         // added detail
                float rimSpd1  = 1.25;                         // angular scroll speeds
                float rimSpd2  = -1.75;

                // wobbling edge radius (sum of two traveling waves)
                float rEdge = rimBase + rimAmp * ( sin(rimAng * rimFreq1 + rimT * rimSpd1)
                                       + 0.5 * sin(rimAng * rimFreq2 + rimT * rimSpd2) );

                // anti-aliased line
                float rimHalf = 0.006;// line half-width
                float rimMask = 1.0 - smoothstep(-1.5*aa, 1.5*aa, abs(length(uv) - rEdge) - rimHalf);

                // ripple color
                float3 rimCol = float3(0.30, 0.65, 0.95);

                col = lerp(col, rimCol, rimMask);


                */
                
                // Irregular outer ripples: outward only, layered, visible but same look
                float tNow         = _hour*3600.0 + _minute*60.0 + _second;  // continuous time
                float dropInterval = 3.0;
                int   N            = 6;

                // Start slightly INSIDE so the first ring is always visible at the dial edge
                float rStart = rDial - 0.010;     // was rDial + 0.006
                float speed  = 0.045;             // slower expansion (was 0.060)
                float baseW  = 0.024;             // a bit thicker (was 0.018)
                float lifeK  = 0.20;              // longer life (was 0.28)

                // Blend masks: begin a touch inside, and widen the edge band
                float outMask  = smoothstep(rDial - 0.02, rDial + 1.30, rr);     // was (-0.00, +1.30)
                float edgeHalo = smoothstep(rDial - 0.10, rDial + 0.03,  rr);     // was (-0.040, +0.015)

                // Slightly brighter ripple blue vs water for contrast
                float3 rippleCol = lerp(colRippleBlue, colWaterDeep, 0.35);       // was 0.45

                float ripAccumOut  = 0.0;
                float ripAccumEdge = 0.0;
                float baseIdx  = floor(tNow / dropInterval);
                float angR     = atan2(uv.y, uv.x);

                [unroll]
                for (int j=0; j<N; j++)
                {
                    float bornAt = (baseIdx - j) * dropInterval;
                    float t      = tNow - bornAt;
                    if (t < 0.0) continue;

                    // quicker fade-in to ensure the first ring shows, then slower fade-out
                    float appear = smoothstep(0.0, 0.30, t);        // was 0.45
                    float env    = appear * exp(-lifeK * t);        // lifeK lowered above

                    // outward-only radius
                    float R = rStart + speed * t;

                    // same multi-frequency warble and width modulation
                    float seed   = hash11(23.17 + j*4.21);
                    float phase  = t*0.9 + seed*6.2831;
                    float warble = (sin(angR*5.0  + phase)
                                   +0.6*sin(angR*9.0  - 1.1*phase)
                                   +0.3*sin(angR*15.0 + 0.7*phase))
                                   * (0.008 + 0.003*hash11(seed*3.7));
                    float width  = baseW * (1.0 + 0.40*sin(angR*4.0 + 0.5*phase));

                    float ring = ringGauss(abs(rr - (R + warble)), width) * env;

                    ripAccumOut += ring;

                    // keep the “linger near edge” behavior
                    float nearEdge = exp(-pow(max(0.0, (R - rDial)) / 0.06, 2.0));
                    ripAccumEdge += ring * nearEdge;
                }

                // slightly stronger blending so waves read clearly
                float alphaOut  = saturate(ripAccumOut  * 2.0) * outMask;    // was *1.45
                float alphaEdge = saturate(ripAccumEdge * 1.0) * edgeHalo;   // was *0.65

                water = lerp(water, rippleCol, alphaOut);
                col   = lerp(col,   rippleCol, alphaEdge);

                // Final blend: water outside, dial contents inside
                float dialMask = circleAA(uv, rDial, 2.0*aa);
                col = lerp(water, col, dialMask);
                


                return float4(col, 1);
            }

            ENDHLSL
        }
    }
}