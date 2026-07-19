#import "OverlayView.h"
#import "Config.h"
#import "imgui.h"
#import "imgui_impl_metal.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface OverlayView ()
@property (nonatomic, strong) id<MTLDevice> dev;
@property (nonatomic, strong) MTKView *mtk;
@property (nonatomic, strong) id<MTLCommandQueue> q;
@property (nonatomic, assign) BOOL ok;
@property (nonatomic, assign) BOOL show;
@property (nonatomic, assign) BOOL mini;
@property (nonatomic, assign) float fps;
@property (nonatomic, assign) CFTimeInterval t0;
@property (nonatomic, assign) int ct;
@property (nonatomic, assign) BOOL b;
@property (nonatomic, assign) float f;
@property (nonatomic, assign) int iv;
@property (nonatomic, strong) NSMutableArray *lg;
@end

@implementation OverlayView
@synthesize ok = _ok;

+ (instancetype)shared { static OverlayView *i; static dispatch_once_t d; dispatch_once(&d,^{i=[OverlayView new];}); return i; }

- (instancetype)init {
    self = [super init];
    _show = YES; _mini = NO; _ok = NO;
    _b = NO; _f = 50; _iv = 42;
    _lg = [NSMutableArray array];
    self.userInteractionEnabled = YES;
    self.multipleTouchEnabled = NO;

    _dev = MTLCreateSystemDefaultDevice();
    if (!_dev) return self;
    _q = [_dev newCommandQueue];

    _mtk = [[MTKView alloc] initWithFrame:CGRectZero device:_dev];
    _mtk.contentScaleFactor = UIScreen.mainScreen.scale;
    _mtk.delegate = self;
    _mtk.opaque = NO;
    _mtk.layer.opaque = NO;
    _mtk.backgroundColor = nil;
    _mtk.clearColor = MTLClearColorMake(0,0,0,0);
    _mtk.framebufferOnly = NO;
    _mtk.paused = NO;
    _mtk.enableSetNeedsDisplay = NO;
    _mtk.userInteractionEnabled = NO;
    _mtk.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    _mtk.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    [self addSubview:_mtk];
    return self;
}

- (void)setupImGui {
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO &io = ImGui::GetIO();
    io.IniFilename = NULL;
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
    ImGui::StyleColorsDark();
    ImGui::GetStyle().ScaleAllSizes(1.5f);
    ImFontConfig fc; fc.SizePixels = 18;
    io.Fonts->AddFontDefault(&fc);
    ImGui_ImplMetal_Init(_dev);
    _ok = YES;
}

- (void)start {
    UIWindow *w = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    w.backgroundColor = nil;
    w.opaque = NO;
    w.windowLevel = UIWindowLevelAlert + 100;
    w.hidden = NO;
    [w addSubview:self];

    self.frame = w.bounds;
    _mtk.frame = self.bounds;

    objc_setAssociatedObject(UIApplication.sharedApplication, "xc", w, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [NSNotificationCenter.defaultCenter addObserver:self
        selector:@selector(rot:) name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)rot:(NSNotification*)n {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,500*NSEC_PER_MSEC), dispatch_get_main_queue(),^{
        UIWindow *w = objc_getAssociatedObject(UIApplication.sharedApplication,"xc");
        w.frame = UIScreen.mainScreen.bounds;
        self.frame = w.bounds;
        _mtk.frame = self.bounds;
    });
}

- (void)log:(NSString*)m {
    [_lg addObject:[NSString stringWithFormat:@"%@ %@",
        [NSDateFormatter localizedStringFromDate:NSDate.date dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle], m]];
    if (_lg.count>100) [_lg removeObjectAtIndex:0];
}

#pragma mark - Touch

- (void)touchesBegan:(NSSet<UITouch*>*)ts withEvent:(UIEvent*)e { [self pt:ts dn:YES]; }
- (void)touchesMoved:(NSSet<UITouch*>*)ts withEvent:(UIEvent*)e { [self pt:ts dn:NO]; }
- (void)touchesEnded:(NSSet<UITouch*>*)ts withEvent:(UIEvent*)e { [self pu:ts]; }
- (void)touchesCancelled:(NSSet<UITouch*>*)ts withEvent:(UIEvent*)e { [self pu:ts]; }

- (void)pt:(NSSet<UITouch*>*)ts dn:(BOOL)d {
    if (!_ok) return;
    CGPoint p = [ts.anyObject locationInView:self];
    float s = UIScreen.mainScreen.scale;
    ImGui::GetIO().AddMousePosEvent(p.x*s, p.y*s);
    if (d) ImGui::GetIO().AddMouseButtonEvent(0,true);
}
- (void)pu:(NSSet<UITouch*>*)ts {
    if (!_ok) return;
    ImGui::GetIO().AddMouseButtonEvent(0,false);
}

#pragma mark - MTKView

- (void)mtkView:(MTKView*)v drawableSizeWillChange:(CGSize)sz {
    ImGui::GetIO().DisplaySize = ImVec2(sz.width, sz.height);
}

- (void)drawInMTKView:(MTKView*)v {
    if (!_ok) return;
    ImGui_ImplMetal_NewFrame(v.currentRenderPassDescriptor);
    ImGui::NewFrame();
    [self menu];
    ImGui::Render();
    ImDrawData *dd = ImGui::GetDrawData();
    if (!dd) return;
    MTLRenderPassDescriptor *rp = v.currentRenderPassDescriptor;
    if (!rp) return;
    id<MTLCommandBuffer> cb = [_q commandBuffer];
    id<MTLRenderCommandEncoder> e = [cb renderCommandEncoderWithDescriptor:rp];
    ImGui_ImplMetal_RenderDrawData(dd, cb, e);
    [e endEncoding];
    [cb presentDrawable:v.currentDrawable];
    [cb commit];
}

#pragma mark - Menu

- (void)menu {
    if (!_show) return;

    _ct++;
    CFTimeInterval n = CACurrentMediaTime();
    if (n-_t0 >= FPS_REFRESH_INTERVAL) { _fps=_ct/(n-_t0); _ct=0; _t0=n; }

    float sw = ImGui::GetIO().DisplaySize.x;
    float sh = ImGui::GetIO().DisplaySize.y;
    if (sw<=0) sw=UIScreen.mainScreen.bounds.size.width *UIScreen.mainScreen.scale;
    if (sh<=0) sh=UIScreen.mainScreen.bounds.size.height*UIScreen.mainScreen.scale;

    ImGui::SetNextWindowPos(ImVec2(10,10), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowBgAlpha(0.4f);
    if (ImGui::Begin("fps",0,ImGuiWindowFlags_NoDecoration|ImGuiWindowFlags_AlwaysAutoResize|ImGuiWindowFlags_NoInputs|ImGuiWindowFlags_NoSavedSettings)) {
        ImGui::TextColored(ImVec4(0,1,0,1), "%.0f FPS  %.0fx%.0f s:%.1f", _fps, sw, sh, UIScreen.mainScreen.scale);
        ImGui::End();
    }

    if (_mini) {
        ImGui::SetNextWindowPos(ImVec2(10,60), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowSize(ImVec2(220,48), ImGuiCond_Always);
        if (ImGui::Begin("##bar",0,ImGuiWindowFlags_NoDecoration|ImGuiWindowFlags_NoResize|ImGuiWindowFlags_NoMove|ImGuiWindowFlags_NoSavedSettings)) {
            if (ImGui::Button("Open", ImVec2(200,30))) _mini=NO;
            ImGui::End();
        }
        return;
    }

    float mw = sw*0.5f; if (mw<400)mw=400; if (mw>800)mw=800;
    float mh = sh*0.6f; if (mh<450)mh=450;

    ImGui::SetNextWindowSize(ImVec2(mw,mh), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowPos(ImVec2(20,60), ImGuiCond_FirstUseEver);

    if (!ImGui::Begin("XC Tool", &_show, 0)) { ImGui::End(); return; }

    if (ImGui::Button("_",ImVec2(36,0))) _mini=YES;
    ImGui::SameLine(); ImGui::TextUnformatted("v" APP_VERSION);
    ImGui::Separator();

    if (ImGui::BeginTabBar("t")) {
        if (ImGui::BeginTabItem("Home")) {
            ImGui::Text("Bundle: %s", NSBundle.mainBundle.bundleIdentifier.UTF8String?: "?");
            ImGui::Text("Device: %s", UIDevice.currentDevice.model.UTF8String?: "?");
            ImGui::Text("ios: %s", UIDevice.currentDevice.systemVersion.UTF8String?: "?");
            ImGui::EndTabItem();
        }
        if (ImGui::BeginTabItem("Test")) {
            ImGui::Checkbox("Toggle", &_b);
            ImGui::SliderFloat("Float", &_f,0,100,"%.1f");
            ImGui::SliderInt("Int", &_iv,0,100);
            if (ImGui::Button("Click",ImVec2(-1,40))) { [self log:@"Click"]; _iv++; }
            if (ImGui::Button("Reset",ImVec2(-1,40))) { _f=50;_iv=42;_b=NO; }
            ImGui::EndTabItem();
        }
        if (ImGui::BeginTabItem("Log")) {
            if (ImGui::SmallButton("Clear"))[_lg removeAllObjects];
            ImGui::SameLine(); ImGui::Text("(%lu)",(unsigned long)_lg.count);
            ImGui::Separator();
            ImGui::BeginChild("l",ImVec2(0,0),true);
            for (NSString *m in _lg) ImGui::TextUnformatted(m.UTF8String);
            if (_lg.count>0&&ImGui::GetScrollY()>=ImGui::GetScrollMaxY()) ImGui::SetScrollHereY(1);
            ImGui::EndChild();
            ImGui::EndTabItem();
        }
        ImGui::EndTabBar();
    }
    ImGui::End();
}
@end
