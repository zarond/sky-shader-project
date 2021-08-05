Shader "Custom/rmrchfog"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_Low("Low", Range(0,100)) = 50
		_ExtinctionColor("Extinction Color", Color) = (1.0,1.0,1.0)
		_NoiseDithering("Noise texture", 2D) = "white" {}
		_Noise1("Noise texture 1 ", 2D) = "white" {}
	}
		SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

		Pass
	{
		//Tags{ "LightMode" = "ForwardBase" }

		CGPROGRAM
		#pragma vertex vert
		#pragma fragment frag

		#include "UnityCG.cginc"
		#include "UnityLightingCommon.cginc" // for _LightColor0

		sampler3D _3DTex;
		float4 _ExtinctionColor;
		sampler2D _NoiseDithering;
		uniform float4 _NoiseDithering_TexelSize;
		float _Low;
		sampler2D _Noise1;
		uniform sampler2D m_ShadowmapCopy;

	struct appdata
	{
		float4 vertex : POSITION;
		float2 uv : TEXCOORD0;
	};

	struct v2f
	{
		float2 uv : TEXCOORD0;
		float4 vertex : SV_POSITION;
		float3 ray: TEXCOORD1;
	};

	float4x4 clipToWorld;

	inline float rand(float3 myVector) {
		return frac(sin(_Time[0] * dot(myVector, float3(12.9898, 78.233, 45.5432))) * 43758.5453);
	}

	inline float rand1(float3 myVector) {
		return tex2D(_NoiseDithering, _Time[3] + (myVector + 0.5) * _NoiseDithering_TexelSize.xy).r;
	}

	inline float rand2(float3 myVector) {
		float2 interleavedPos = (fmod(floor(myVector.xy), 4.0));
		return tex2D(_NoiseDithering, interleavedPos / 4.0 + float2(0.5 / 4.0, 0.5 / 4.0)).w;
	}

	inline float HenyeyGreenstein(float cos_angle, float eccentricity) {
		const float pi = 3.14159;
		return ((1 - eccentricity * eccentricity) / pow((1 + eccentricity * eccentricity - 2 * eccentricity*cos_angle), 3 / 2)) / 4 * pi;
	}

	inline float sample_density(float3 V) {
		//return tex3D(_3DTex, V);
		//return tex2D(_Noise1, V.xz/200);
		//return tex2D(_Noise1, V.xz / 200) * tex2D(_Noise1, V.xz / 800);
		return 1.0;
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


	v2f vert(appdata v)
	{
		v2f o;

		o.vertex = UnityObjectToClipPos(v.vertex);
		o.uv = v.uv;

		float4 clip = float4(o.vertex.xy, 0.0, 1.0);
		o.ray = mul(clipToWorld, clip) - _WorldSpaceCameraPos;

		return o;
	}

	sampler2D _MainTex;
	sampler2D_float _CameraDepthTexture;
	float4 _CameraDepthTexture_ST;

	//#define _JITTER
	#define _HGFUNCTION
	//#define _GRADIENTBLEND
	#define _SHADOWS;

	fixed4 frag(v2f i) : SV_Target
	{
	float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv.xy);
	depth = LinearEyeDepth(depth);
	float3 worldspace = i.ray * depth + _WorldSpaceCameraPos;

	float3 rayDirection = normalize(i.ray.xyz);

	int N = 64;
	const int Nsh = 10;
	float size = 1;
	float steps = 2 * size;
	float shadowsteps = 4 * size;

	float3 Vec = 0;

	float3 V, V2;

	float curdensity = 0;
	float cursample = 0;
	float3 lightenergy = 0;
	float transmittance = 1;
	float density = 0.01 / size;
	float3 shadowdensity = 0.005 / (size *_ExtinctionColor);
	float AmbientDensity = 0.003 / size;

	density *= steps;
	shadowdensity *= shadowsteps;

	// calculate number of steps;
	//float intersection = (_Low - _WorldSpaceCameraPos.y) / rayDirection.y;
	//if (rayDirection.y < 0.01 || (depth - intersection)<0) return tex2D(_MainTex, i.uv);
	//Vec = rayDirection * (_Low - _WorldSpaceCameraPos.y) / rayDirection.y;
	//N = min(int((depth - (_Low - _WorldSpaceCameraPos.y) / rayDirection.y)/steps), N);
	N = min(int(length(i.ray) * depth/steps), N);
	N = max(N, 0);

#if defined (_JITTER)
	// Temporal jitter: вещь хорошая но надо бы оптимизировать
	float Jitter = 1 * steps;
	Vec += rayDirection * rand1(float3(i.uv, 1)) * Jitter;
#endif

	//[loop]
	for (int j = 0; j<N; ++j) {
		V = _WorldSpaceCameraPos + Vec;
		if ((cursample = sample_density(V))>0.001)
		{
			float3 Vec2 = 0;
			float shadowdist = 0;

#if defined (_SHADOWS)
			float4 cascadeWeights = GetCascadeWeights_SplitSpheres(_WorldSpaceCameraPos + Vec);
			bool inside = dot(cascadeWeights, float4(1, 1, 1, 1)) < 4;
			float4 samplePos = GetCascadeShadowCoord(float4(_WorldSpaceCameraPos + Vec, 1), cascadeWeights);
			float atten = tex2D(m_ShadowmapCopy, samplePos.xyz);
#endif

			for (int k = 0; k < Nsh; ++k) {
				V2 = _WorldSpaceCameraPos + Vec + Vec2;
				shadowdist += sample_density(V2);
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
			V = _WorldSpaceCameraPos + Vec + float3(0, 0, 0.05)*size;
			shadowdist += sample_density(V);
			V = _WorldSpaceCameraPos + Vec + float3(0, 0, .1)*size;
			shadowdist += sample_density(V);
			V = _WorldSpaceCameraPos + Vec + float3(0, 0, .2)*size;
			shadowdist += sample_density(V);
			lightenergy += exp(-shadowdist * AmbientDensity) * curdensity * ShadeSH9(float4(0, 0, 0, 1)) * transmittance;
		}
		//}// else break;
		Vec += rayDirection * steps;
	}

	//return float(N)/100;

	float3 color;
#if defined (_GRADIENTBLEND)
	float grad = pow(rayDirection.y - 0.01,0.25);
	transmittance += 1 - grad;
	//return fixed4(grad, grad, grad, grad);
#endif

#if defined (_HGFUNCTION)
	color = lightenergy * HenyeyGreenstein(dot(normalize(_WorldSpaceLightPos0.xyz), rayDirection), 0.2);
	return fixed4(color*(1 - transmittance) + transmittance * tex2D(_MainTex, i.uv), 1);
#endif

	//return fixed4(lightenergy,1);
	color = lightenergy;
	return fixed4(color*(1 - transmittance) + transmittance * tex2D(_MainTex, i.uv),1);

	//float4 color = float4(rayDirection, 1.0);
	//return depth/100 + tex2D(_MainTex,i.uv);
	//return tex2D(_MainTex, i.uv);
	}
		ENDCG
	}
	}
}
