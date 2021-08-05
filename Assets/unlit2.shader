// Upgrade NOTE: replaced 'unity_World2Shadow' with 'unity_WorldToShadow'

// Upgrade NOTE: replaced 'unity_World2Shadow' with 'unity_WorldToShadow'

Shader "Unlit/unlit2"
{
	Properties
	{
		_3DTex("Texture", 3D) = "white" {}
		_ExtinctionColor("Extinction Color", Color) = (1.0,1.0,1.0)
		_NoiseDithering("Noise texture", 2D) = "white" {}
		_N ("Number of samples", Int) = 96
		_Nsh ("Number of shadow samples", Int) = 24
		_density ("density",Float) = 10
		_shadowdensity("shadow density",Float) = 5
		_Ambientdensity("ambient density",Float) = 0.5
	}
		SubShader
	{
		Tags{ "Queue" = "Transparent" "RenderType" = "Transparent" }

		LOD 100

		ZWrite Off
		Blend SrcAlpha OneMinusSrcAlpha
		//Blend One One
		//Blend DstColor Zero

		Pass
	{
		Tags{ "LightMode" = "ForwardBase" }

		CGPROGRAM
		#pragma vertex vert
		#pragma fragment frag
		#pragma target 3.0
		#pragma multi_compile_fwdbase

		#include "UnityCG.cginc"
		#include "UnityLightingCommon.cginc" // for _LightColor0
		//#include "AutoLight.cginc"

		uniform vector origin;
		uniform float3 size;

		sampler3D _3DTex;
		sampler2D _NoiseDithering;
		uniform float4 _NoiseDithering_TexelSize;
		uniform int _N;
		uniform int _Nsh;
		uniform float _density;
		uniform float _shadowdensity;
		uniform float _Ambientdensity;

		uniform sampler2D m_ShadowmapCopy;
		//sampler2D _CameraDepthTexture;
		//UNITY_DECLARE_SHADOWMAP(_ShadowMapTexture);
		//uniform sampler2D _ShadowMapTexture;
		float4 _MainTex_ST;
		float4 _ExtinctionColor;

		inline float sample_density(float3 V) {
			return tex3D(_3DTex, V);
		}

		inline bool boxtest(float3 V) {
			return (V.x<1.0 && V.x>0.0 &&
					V.y<1.0 && V.y>0.0 &&
					V.z<1.0 && V.z>0.0);
		}

		inline bool boxtest1(float3 V) {
			float3 shadowboxtest = floor(0.5 + (abs(0.5 - V)));
			//float exitshadowbox = shadowboxtest.x + shadowboxtest.y + shadowboxtest.z;
			return (shadowboxtest.x + shadowboxtest.y + shadowboxtest.z < 1) ;
		}

		inline float rand(float3 myVector) {
			return frac(sin(_Time[0] * dot(myVector ,float3(12.9898,78.233,45.5432))) * 43758.5453);
		}

		inline float rand1(float3 myVector) {
			return tex2D(_NoiseDithering, _Time[3] + (myVector + 0.5) * _NoiseDithering_TexelSize.xy).r;
		}

		inline float rand2(float3 myVector) {
			float2 interleavedPos = (fmod(floor(myVector.xy), 4.0));
			return tex2D(_NoiseDithering, interleavedPos / 4.0 + float2(0.5 / 4.0, 0.5 / 4.0)).w;
		}

		inline float HenyeyGreenstein(float cos_angle,float eccentricity) {
			const float pi = 3.14159;
			return ((1 - eccentricity * eccentricity) / pow((1 + eccentricity * eccentricity - 2 * eccentricity*cos_angle),3 / 2)) / 4 * pi;
		}

		inline fixed4 GetCascadeWeights_SplitSpheres(float3 wpos)
		{
			float3 fromCenter0 = wpos.xyz - unity_ShadowSplitSpheres[0].xyz;
			float3 fromCenter1 = wpos.xyz - unity_ShadowSplitSpheres[1].xyz;
			float3 fromCenter2 = wpos.xyz - unity_ShadowSplitSpheres[2].xyz;
			float3 fromCenter3 = wpos.xyz - unity_ShadowSplitSpheres[3].xyz;
			float4 distances2 = float4(dot(fromCenter0, fromCenter0), dot(fromCenter1, fromCenter1), dot(fromCenter2, fromCenter2), dot(fromCenter3, fromCenter3));

			fixed4 weights = float4(distances2 < unity_ShadowSplitSqRadii);
			weights.yzw = saturate(weights.yzw - weights.xyz);
			return weights;
		}

		//-----------------------------------------------------------------------------------------
		// GetCascadeShadowCoord
		//-----------------------------------------------------------------------------------------
		inline float4 GetCascadeShadowCoord(float4 wpos, fixed4 cascadeWeights)
		{
			float3 sc0 = mul(unity_WorldToShadow[0], wpos).xyz;
			float3 sc1 = mul(unity_WorldToShadow[1], wpos).xyz;
			float3 sc2 = mul(unity_WorldToShadow[2], wpos).xyz;
			float3 sc3 = mul(unity_WorldToShadow[3], wpos).xyz;

			float4 shadowMapCoordinate = float4(sc0 * cascadeWeights[0] + sc1 * cascadeWeights[1] + sc2 * cascadeWeights[2] + sc3 * cascadeWeights[3], 1);
#if defined(UNITY_REVERSED_Z)
			float  noCascadeWeights = 1 - dot(cascadeWeights, float4(1, 1, 1, 1));
			shadowMapCoordinate.z += noCascadeWeights;
#endif
			return shadowMapCoordinate;
		}

		inline float2 intersection(float3 ray, float3 origin) {
			float t[6];
			t[0] = -origin.x / ray.x;
			t[1] = -origin.y / ray.y;
			t[2] = -origin.z / ray.z;
			t[3] = -(origin.x - 1) / ray.x;
			t[4] = -(origin.y - 1) / ray.y;
			t[5] = -(origin.z - 1) / ray.z;
                   
            float s=0;
			if (t[0] > t[3]) { s = t[0]; t[0] = t[3]; t[3] = s;}
			if (t[1] > t[4]) { s = t[1]; t[1] = t[4]; t[4] = s;}
			if (t[2] > t[5]) { s = t[2]; t[2] = t[5]; t[5] = s;}
            
			return float2(max(max(max(t[0], t[1]), t[2]),0), min(min(t[3], t[4]), t[5]));         
		}

		inline float2 intersectionF(float3 ray, float3 origin) {
			float3 t[2];
			t[0] = -origin / ray;
			t[1] = -(origin-1) / ray;

			float s = 0;
			if (t[0].x > t[1].x) { s = t[0].x; t[0].x = t[1].x; t[1].x = s; }
			if (t[0].y > t[1].y) { s = t[0].y; t[0].y = t[1].y; t[1].y = s; }
			if (t[0].z > t[1].z) { s = t[0].z; t[0].z = t[1].z; t[1].z = s; }

			return float2(max(max(max(t[0].x, t[0].y), t[0].z), 0), min(min(t[1].x, t[1].y), t[1].z));
		}


	struct v2f
	{
		float2 uv : TEXCOORD0;
		float3 ray : TEXCOORD1;
		float4 _ShadowCoord: TEXCOORD2;

	};

	v2f vert(
		float4 vertex : POSITION,
		float2 uv : TEXCOORD0,
		out float4 outpos : SV_POSITION
	)
	{
		v2f o;
		o.uv = TRANSFORM_TEX(uv, _MainTex);
		o.ray = mul(unity_ObjectToWorld, vertex);
		outpos = UnityObjectToClipPos(vertex);		
		o._ShadowCoord = mul(unity_WorldToShadow[0], o.ray);
		return o;
	}
	
	fixed4 frag(v2f i, UNITY_VPOS_TYPE vpos : VPOS) : SV_Target
	{
		//#define _JITTER
		#define _HGFUNCTION
	    #define _PLANESTEPSNAP
		//#define _SHADOWS;

		//float depth = tex2D(_CameraDepthTexture, i.uv).r;
		//depth = Linear01Depth(depth);

		float3 rayDirection = normalize((i.ray - _WorldSpaceCameraPos).xyz);

		/*int N = 64;
		int Nsh = 24;
		float steps = (1.74 / N) * size.x;
		float shadowsteps = (1.74 / Nsh) * size.x;*/
		int N = _N;
		int Nsh = _Nsh;
		float steps = (1.74 / N) * size.x;
		float shadowsteps = (1.74 / Nsh) * size.x;

		float3 V,V2;

		float curdensity = 0;
		float cursample = 0;
		float3 lightenergy = 0;
		float transmittance = 1;
		float density = _density / size.x;
		float3 shadowdensity = _shadowdensity / ( size.x *_ExtinctionColor);
		float AmbientDensity = _Ambientdensity / size.x;

		density *= steps;
		shadowdensity *= shadowsteps;       

		//intersection
		float2 intersect = intersectionF(mul(unity_WorldToObject, rayDirection).xyz, mul(unity_WorldToObject, _WorldSpaceCameraPos.xyz - origin).xyz + float3(0.5, 0.5, 0.5));
        
#if defined (_PLANESTEPSNAP)
        //intersect.x += (1-frac((intersect.x - length(_WorldSpaceCameraPos.xyz - origin))*64 ))/64;
      //intersect.x = (dot(-_WorldSpaceCameraPos + origin,rayDirection)-0.87*size.x) + ceil((intersect.x - (dot(-_WorldSpaceCameraPos + origin,rayDirection)-0.87*size.x))/steps)*steps;
        intersect.x = (dot(-_WorldSpaceCameraPos + origin,rayDirection)-0.87*size.x);
        //intersect.x = floor(intersect.x/steps)*steps;
#endif

		float3 Vec = intersect.x * rayDirection;
		N = max(1, int((intersect.y - intersect.x) / steps));
		N = min(N, N); 
        
#if defined (_JITTER)
        // Temporal jitter: вещь хорошая но надо бы оптимизировать
        float Jitter = 0.9 * steps;
        Vec += rayDirection * rand(vpos) * Jitter;
#endif


		[loop]
		for (int j = 0; j<N; ++j) {
			V = mul(unity_WorldToObject,_WorldSpaceCameraPos + Vec - origin) + float3(0.5,0.5,0.5);
			//if (boxtest(V)) {
				if ((cursample = sample_density(V))>0.001)
				{					
					float3 Vec2 = 0;
					float shadowdist = 0;

#if defined (_SHADOWS)
					float4 cascadeWeights = GetCascadeWeights_SplitSpheres(_WorldSpaceCameraPos + Vec);
					bool inside = dot(cascadeWeights, float4(1, 1, 1, 1)) < 4;
					float4 samplePos = GetCascadeShadowCoord(float4(_WorldSpaceCameraPos + Vec, 1), cascadeWeights);

					//float atten = inside ? UNITY_SAMPLE_SHADOW( m_ShadowmapCopy, samplePos.xyz) : 1.0f;
					//float atten = inside ? tex2D(m_ShadowmapCopy, samplePos.xyz) : 1.0f;
					float atten = tex2D(m_ShadowmapCopy, samplePos.xyz);
					//atten = (atten > samplePos.z) ? 1 : 0;
					//if (samplePos.z > atten) {
#endif
					// пересечение с кубом для shadow ray
					//float2 intersectsh = intersection(mul(unity_WorldToObject, _WorldSpaceLightPos0.xyz).xyz, mul(unity_WorldToObject, _WorldSpaceCameraPos.xyz + Vec - origin).xyz + float3(0.5, 0.5, 0.5));
					//Nsh = max(1, int((intersectsh.y) / shadowsteps));
					//Nsh = min(Nsh, 24);
						[loop]
						for (int k = 0; k < Nsh; ++k) {
							V2 = mul(unity_WorldToObject, _WorldSpaceCameraPos + Vec + Vec2 - origin) + float3(0.5, 0.5, 0.5);
							if (boxtest1(V2))	shadowdist += sample_density(V2); else break;
							//shadowdist += sample_density(V2); 
							Vec2 += shadowsteps * normalize(_WorldSpaceLightPos0.xyz);

						}

					curdensity = saturate(cursample * density);
					float3 shadowterm = exp(-shadowdist * shadowdensity);
					float3 absorbedlight = shadowterm * curdensity;
#if defined (_SHADOWS)
					lightenergy += ((samplePos.z > atten) ? _LightColor0 : ShadeSH9(float4(0, 0, 0, 1))) * absorbedlight * transmittance;
#else
					lightenergy += _LightColor0 * absorbedlight * transmittance;
#endif
					transmittance *= 1 - curdensity;

					//ambient
					shadowdist = 0;
					V = mul(unity_WorldToObject,_WorldSpaceCameraPos + Vec + float3(0,0,0.05)*size.x - origin) + float3(0.5,0.5,0.5);
					shadowdist += sample_density(V);
					V = mul(unity_WorldToObject,_WorldSpaceCameraPos + Vec + float3(0,0,.1)*size.x - origin) + float3(0.5,0.5,0.5);
					shadowdist += sample_density(V);
					V = mul(unity_WorldToObject,_WorldSpaceCameraPos + Vec + float3(0,0,.2)*size.x - origin) + float3(0.5,0.5,0.5);
					shadowdist += sample_density(V);
					lightenergy += exp(-shadowdist * AmbientDensity) * curdensity * ShadeSH9(float4(0,1,0,1)) * transmittance;
				}
			//}
			Vec += rayDirection * steps;
			if (transmittance < 0.002) { transmittance = 0; break; }
		}


#if defined (_HGFUNCTION)
		return fixed4(lightenergy * HenyeyGreenstein(dot(normalize(_WorldSpaceLightPos0.xyz),rayDirection),0.2),1 - transmittance);
#endif

		//return (intersect.y - intersect.x)/2;
        //return float(N)/64;
        //return fixed4(lightenergy,1);
		return fixed4(lightenergy,1 - transmittance);

	}
		ENDCG
	}
	}
}
