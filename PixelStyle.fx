float ScnUse: CONTROLOBJECT < string name = "PixelStyleController.pmx"; string item = "UseScreenSample"; >;
float FC: CONTROLOBJECT < string name = "PixelStyleController.pmx"; string item = "FC"; >;
float EightBit: CONTROLOBJECT < string name = "PixelStyleController.pmx"; string item = "EightBit"; >;
float Win98: CONTROLOBJECT < string name = "PixelStyleController.pmx"; string item = "Win98"; >;
float Custom: CONTROLOBJECT < string name = "PixelStyleController.pmx"; string item = "Custom"; >;

#define VIEWPORT_RATIO 0.25
#define AA_FLG false


float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;



float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

static float2 SampStep = (float2(1,1)/ViewportSize);


float4 ClearColor = {1,1,1,1};
float ClearDepth  = 1.0;


texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = VIEWPORT_RATIO;
    int MipLevels = 1;
    bool AntiAlias = AA_FLG;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    Filter = NONE;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = VIEWPORT_RATIO;
    string Format = "D24S8";
>;

texture EdgeRT: OFFSCREENRENDERTARGET <
    string Description = "PixelShader Using Edge.fx";
    float2 ViewPortRatio = VIEWPORT_RATIO;
    float4 ClearColor = { 1, 1, 1, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = AA_FLG;
    string DefaultEffect = 
        "* = Edge.fx";
>;


texture DefaultTex
<
   string ResourceName = "default.png";
   float width = 255.0;
   float height = 1.0;
>;
sampler DefaultView = sampler_state {
    texture = <DefaultTex>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    Filter = NONE;
};

texture Win98Tex
<
   string ResourceName = "win98.png";
   float width = 255.0;
   float height = 1.0;
>;
sampler Win98View = sampler_state {
    texture = <Win98Tex>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    Filter = NONE;
};

texture FCTex
<
   string ResourceName = "FC.png";
   float width = 255.0;
   float height = 1.0;
>;
sampler FCView = sampler_state {
    texture = <FCTex>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    Filter = NONE;
};

texture EightBitTex
<
   string ResourceName = "EightBit.png";
   float width = 255.0;
   float height = 1.0;
>;
sampler EightBitView = sampler_state {
    texture = <EightBitTex>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    Filter = NONE;
};

texture CustomTex
<
   string ResourceName = "Custom.png";
   float width = 255.0;
   float height = 1.0;
>;
sampler CustomView = sampler_state {
    texture = <CustomTex>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    Filter = NONE;
};


texture TileTex
<
   string ResourceName = "tile.png";
   float width = 64.0;
   float height = 8.0;
>;
sampler TileView = sampler_state {
    texture = <TileTex>;
    AddressU  = WRAP;
    AddressV = WRAP;
    Filter = NONE;
};


struct VS_OUTPUT {
    float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};



sampler EdgeView = sampler_state {
    texture = <EdgeRT>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    Filter = NONE;
};

VS_OUTPUT VS_passMain( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos; 
    Out.Tex = Tex + float2(ViewportOffset.x, ViewportOffset.y);

    return Out;
}
#define OFFSET (8.0/64.0)
float4 PS_passMain(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 w = 1;
    float4 Color = 1;
    if (ScnUse == 1) {
	Color = tex2D(ScnSamp,Tex);
	} else {
	Color = tex2D(EdgeView,Tex);
	}
    float4 TgtCol = 0;
    float4 TgtCol2 = 0;
    float min = 0xffff;
    float min2 = 0xffff;
    
    for(int i=0;i<254;i++)
    {
    	float fi = i;
		
    	w = tex2D(DefaultView,float2(fi/255.0,0.5));
        if (Win98) {
		w = tex2D(Win98View,float2(fi/255.0,0.5));
		}
		if (EightBit) {
		w = tex2D(EightBitView,float2(fi/255.0,0.5));
		}
		if (FC) {
		w = tex2D(FCView,float2(fi/255.0,0.5));
		}
		if (Custom) {
		w = tex2D(CustomView,float2(fi/255.0,0.5));
		}
    	float len = length(w.rgb - Color.rgb);
    	if(len <= min)
    	{
    		min2 = min;
    		min = len;
    		TgtCol2 = TgtCol;
    		TgtCol = w;
    	}
    }

    float tgtlen = saturate(length(min-min2)*16);
    float2 TileTex = Tex/(ViewportOffset*16/VIEWPORT_RATIO);
    TileTex = (TileTex/float2(8,1))%float2(OFFSET,1)+float2(OFFSET*(int(tgtlen*8)),0);
    float Tile = tex2D(TileView,TileTex).r;    
    
    TgtCol = lerp(TgtCol,TgtCol2,Tile);
    TgtCol.a = 1;
    
    return TgtCol;
}

technique Dot <
    string Script = 
        "RenderColorTarget0=ScnMap;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "ScriptExternal=Color;"
        
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "Pass=Main;"
    ;
> {

    pass Main < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 VS_passMain();
        PixelShader  = compile ps_3_0 PS_passMain();
    }
}