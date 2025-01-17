#ifndef CETO_SURFACESHADER_BODY_INCLUDED
#define CETO_SURFACESHADER_BODY_INCLUDED

struct appdata_ceto
{
	float4 vertex : POSITION;
	float4 tangent : TANGENT;
	float3 normal : NORMAL;
	float2 texcoord : TEXCOORD0;
};

struct Input 
{
	float4 wPos;
	float4 screenUV;
	float4 grabUV;
	float4 texUV;
};

void OceanVert(inout appdata_ceto v, out Input OUT) 
{
	
	UNITY_INITIALIZE_OUTPUT(Input, OUT);
	
	float4 uv = float4(v.vertex.xy, v.texcoord.xy);

	float4 oceanPos;
	float3 displacement;
	OceanPositionAndDisplacement(uv, oceanPos, displacement);
	
	v.vertex.xyz = oceanPos.xyz + displacement;
	
	v.tangent = float4(1,0,0,1);
	
	#ifdef CETO_OCEAN_TOPSIDE
		v.normal = float3(0,1,0);
	#else
		v.normal = float3(0,-1,0);
	#endif
	
	OUT.wPos = float4(v.vertex.xyz, COMPUTE_DEPTH_01);
	OUT.texUV = uv;

	float4 screenPos = mul(UNITY_MATRIX_MVP, v.vertex);

	float4 screenUV = ComputeScreenPos(screenPos);
	screenUV = UNITY_PROJ_COORD(screenUV);

	float4 grabUV = ComputeGrabScreenPos(screenPos);
	grabUV = UNITY_PROJ_COORD(grabUV);

	OUT.screenUV = screenUV;
	OUT.grabUV = grabUV;
	
} 

void OceanSurfTop(Input IN, inout SurfaceOutputOcean o) 
{
	
	float4 uv = IN.texUV;
	float3 worldPos = IN.wPos.xyz;
	float depth = IN.wPos.w;

	float4 screenUV;
	screenUV.xy = IN.screenUV.xy / IN.screenUV.w;
	screenUV.zw = IN.grabUV.xy / IN.grabUV.w;
	
	float4 st = WorldPosToProjectorSpace(worldPos);
	OceanClip(st, worldPos);
			
	half3 norm1, norm2, norm3;
	fixed4 foam;
	
	half3 view = normalize(_WorldSpaceCameraPos-worldPos);
	float dist = length(_WorldSpaceCameraPos-worldPos);

	#ifdef CETO_USE_4_SPECTRUM_GRIDS

		//If 4 grids are being used use 3 normals where...
		//norm1 is grid 0 + 1
		//norm2 is grid 0 + 1 + 2
		//norm3 is grid 0 + 1 + 2 + 3
		//This is done so the shader can use normals of different detail
		OceanNormalAndFoam(uv, st, worldPos, norm1, norm2, norm3, foam);
		
		if(dot(view, norm1) < 0.0) norm1 = reflect(norm1, view);
		if(dot(view, norm2) < 0.0) norm2 = reflect(norm2, view);
		if(dot(view, norm3) < 0.0) norm3 = reflect(norm3, view);

	#else

		//If 2 or 1 grid is being use just use one normal
		//It then needs to be applied to norm1, nor2 and norm3.
		half3 norm;
		OceanNormalAndFoam(uv, st, worldPos, norm, foam);

		if (dot(view, norm) < 0.0) norm = reflect(norm, view);

		norm1 = norm;
		norm2 = norm;
		norm3 = norm;

	#endif
	
	fixed3 sky = ReflectionColor(norm2, screenUV.xy);
	
	fixed3 sea = OceanColorFromAbove(norm2, screenUV, worldPos, depth, dist);
	
	sea += SubSurfaceScatter(view, norm1, worldPos.y);
	
	fixed fresnel = FresnelAirWater(view, norm3);
	
	fixed3 col = fixed3(0,0,0);
	
	col += sky * fresnel;
	
	col += sea * (1.0-fresnel);

	col = OceanWithFoamColor(worldPos, col, foam);
	
	#ifndef CETO_DISABLE_EDGE_FADE

		float edgeFade = EdgeFade(screenUV, view, worldPos);
	
		#ifdef CETO_OPAQUE_QUEUE
			fixed3 grab = tex2D(Ceto_RefractionGrab, screenUV.zw).rgb;
			col = lerp(grab, col, edgeFade);
			o.Alpha = 1.0;
			o.LightMask = 1.0 - edgeFade;
		#endif
		
		#ifdef CETO_TRANSPARENT_QUEUE
			o.Alpha = edgeFade;
			o.LightMask = 0.0;
		#endif
		
	#else
		o.Alpha = 1.0;
		o.LightMask = 0.0;
	#endif

	o.Albedo = col;
	o.Normal = TangentSpaceNormal(norm3);
	o.DNormal = norm3;
	o.Fresnel = fresnel;

}

void OceanSurfUnder(Input IN, inout SurfaceOutputOcean o) 
{

	float4 uv = IN.texUV;
	float3 worldPos = IN.wPos.xyz;
	float depth = IN.wPos.w;

	float4 screenUV;
	screenUV.xy = IN.screenUV.xy / IN.screenUV.w;
	screenUV.zw = IN.grabUV.xy / IN.grabUV.w;
	
	float4 st = WorldPosToProjectorSpace(worldPos);
	OceanClip(st, worldPos);
	
	half3 norm;
	fixed4 foam;
	OceanNormalAndFoam(uv, st, worldPos, norm, foam);
	norm.y *= -1.0;
		
	half3 view = normalize(_WorldSpaceCameraPos-worldPos);
	float dist = length(_WorldSpaceCameraPos-worldPos);

	if (dot(view, norm) < 0.0) norm = reflect(norm, view);
	
	fixed3 sky = SkyColorFromBelow(norm, screenUV, worldPos, depth, dist);
	
	fixed3 sea = DefaultUnderSideColor();
	
	float fresnel = FresnelWaterAir(view, norm);

	fixed3 col = fixed3(0,0,0);
	
	col += sea * fresnel;
	
	col += sky * (1.0-fresnel);
	
	col = OceanWithFoamColor(worldPos, col, foam);

	o.Albedo = col;
	o.Normal = TangentSpaceNormal(norm);
	o.DNormal = norm;
	o.Fresnel = fresnel;
	o.Alpha = 1.0;
	o.LightMask = 0.0;

}

		
#endif



