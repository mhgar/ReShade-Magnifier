uniform float2 DrawPosition <
	ui_type = "drag";
	ui_min = 0.0; 
	ui_max = 1.0;
	ui_step = 0.001;
	ui_tooltip = "The position on your on screen where the magnifier will draw (does not work in when the magnifier is set to fullscreen).";
> = float2(0.5, 0.5);

uniform float2 MagnifyPosition <
	ui_type = "drag";
	ui_min = 0.0; 
	ui_max = 1.0;
	ui_step = 0.001;
	ui_tooltip = "The position on your on screen that the magnifier will magnify (you'll probably want to leave this at (0.5, 0.5)).";
> = float2(0.5, 0.5);

uniform int Shape <
	ui_type = "combo";
	ui_type = "combo";
	ui_items = "Circle\0Rectangle\0Fullscreen\0";
	ui_tooltip = "Choose the shape of the magnifier.";
> = 0;

uniform int Filtering <
	ui_type = "combo";
	ui_items = "Linear\0Point\0";
	ui_tooltip = "Choose either linear or no filtering for the output image.";
> = 0;

uniform float CircleRadius <
	ui_type = "drag";
	ui_min = 0.0; 
	ui_max = 1000.0;
	ui_step = 1.0;
	ui_tooltip = "The radius in pixels of the magnifier when it is drawn as a circle.";
> = 250.0;

uniform float2 RectangleHalfExtent <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1000.0;
	ui_step = 1.0;
	ui_tooltip = "The half size of the magnifier in pixels when it is drawn as a rectangle.";
> = float2(300.0, 200.0);

uniform float ZoomLevel <
	ui_type = "drag";
	ui_min = 1.0; 
	ui_max = 10.0;
	ui_step = 0.01;
	ui_tooltip = "How much the magnifier will scale things.";
> = 2.5;

uniform float MagnifierOpacity <
	ui_type = "drag";
	ui_min = 0.0; 
	ui_max = 1.0;
	ui_step = 0.001;
	ui_tooltip = "How much opacity the magnifier has.";
> = 1.0;

#include "ReShade.fxh"

#define MODE_CIRCLE 0
#define MODE_RECTANGLE 1
#define MODE_FULLSCREEN 2
#define FILTER_LINEAR 0
#define FILTER_POINT 1

sampler2D pointBuffer {
	Texture   = ReShade::BackBufferTex;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
	AddressU  = BORDER;
	AddressV  = BORDER;
};

// Does ReShade even have math functions? Please tell me where they are :v
int abs(float n) { return n < 0 ? -n : n; }
float2 uv_to_screen(float2 uv) { return float2(uv.x * ReShade::ScreenSize.x, uv.y * ReShade::ScreenSize.y); }
bool outside_bounds(float2 p) { return p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0; }

bool is_in_circle(float2 p, float2 centre, float radius) {
	return (p.x - centre.x) * (p.x - centre.x) + 
	       (p.y - centre.y) * (p.y - centre.y) <=
		   radius * radius;
}

bool is_in_rect(float2 p, float2 centre, float2 half_extent) {
	return abs(p.x - centre.x) <= half_extent.x && abs(p.y - centre.y) <= half_extent.y;
}

float4 PS_Magnifier(float4 pos : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET {
	float scale = 1.0 / ZoomLevel;
	
	// Don't respect the user defined magnifier position if fullscreen has been selected.
	float2 draw_pos = Shape == MODE_FULLSCREEN ? float2(0.5, 0.5) : DrawPosition;
	
	// Decide whether this pixel is within the drawing area of the magnifier.
	bool magnifiy = (Shape == MODE_CIRCLE && is_in_circle(uv_to_screen(uv), uv_to_screen(draw_pos), CircleRadius)) ||
					(Shape == MODE_RECTANGLE && is_in_rect(uv_to_screen(uv), uv_to_screen(draw_pos), RectangleHalfExtent)) ||
					(Shape == MODE_FULLSCREEN);	
	
	if (magnifiy) {
		// Essentially offset from the magnifier and take a pixel to magnify (and there's also some scaling stuff, too).
		float2 offset = uv - draw_pos;
		float2 take_pos = MagnifyPosition + offset * scale;
		float4 behind_pixel = tex2D(ReShade::BackBuffer, uv);
		
		if (outside_bounds(take_pos)) {
			return float4(0.0, 0.0, 0.0, 1.0);
		} else {
			return lerp(behind_pixel, Filtering == FILTER_LINEAR ? tex2D(ReShade::BackBuffer, take_pos) : tex2D(pointBuffer, take_pos), MagnifierOpacity);
		}
	} else {
		return tex2D(ReShade::BackBuffer, uv);
	}
}

technique Magnifier {
	pass {
		VertexShader = PostProcessVS;
		PixelShader = PS_Magnifier;
	}
}
