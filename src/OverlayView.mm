#import "OverlayView.h"
#import "Config.h"
#import "imgui.h"
#import "imgui_impl_metal.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface OverlayView ()
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) MTKView *metalView;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, assign) BOOL ready;
@property (nonatomic, assign) BOOL visible;
@property (nonatomic, assign) BOOL minimized;
@property (nonatomic, assign) float fps;
@property (nonatomic, assign) CFTimeInterval fpsTime;
@property (nonatomic, assign) int fpsCount;
@property (nonatomic, assign) BOOL tb;
@property (nonatomic, assign) float tf;
@property (nonatomic, assign) int ti;
@property (nonatomic, strong) NSMutableArray *log;
@end

@implementation OverlayView

@synthesize ready = _ready;

+ (instancetype)shared {
    static OverlayView *i;
    static dispatch_once_t o;
    dispatch_once(&o, ^{ i = [OverlayView new]; });
    return i;
}

- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    _visible = YES;
    _minimized = NO;
    _ready = NO;
    _tb = NO; _tf = 50; _ti = 42;
    _fps = 0; _fpsTime = 0; _fpsCount = 0;
    _log = [NSMutableArray array];
    self.backgroundColor = UIColor.clearColor;
    self.multipleTouchEnabled = NO;
    self.userInteractionEnabled = YES;

    _device = MTLCreateSystemDefaultDevice();
    if (!_device) return self;
    _commandQueue = [_device newCommandQueue];

    _metalView = [[MTKView alloc] initWithFrame:CGRectZero device:_device];
    _metalView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _metalView.backgroundColor = UIColor.clearColor;
    _metalView.delegate = self;
    _metalView.framebufferOnly = NO;
    _metalView.paused = NO;
    _metalView.enableSetNeedsDisplay = NO;
    _metalView.userInteractionEnabled = NO;
    _metalView.contentScaleFactor = UIScreen.mainScreen.scale;
    [self addSubview:_metalView];
    return self;
}

- (void)setupImGui {
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGui::GetIO().IniFilename = NULL;
    ImGui::GetIO().ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
    ImGui::StyleColorsDark();
    ImGui::GetStyle().ScaleAllSizes(1.5f);

    ImFontConfig fc;
    fc.SizePixels = 18;
    ImGui::GetIO().Fonts->AddFontDefault(&fc);
    ImGui_ImplMetal_Init(_device);
    _ready = YES;
}

- (void)start {
    CGRect r = UIScreen.mainScreen.bounds;
    CGFloat W = MAX(r.size.width, r.size.height);
    CGFloat H = MIN(r.size.width, r.size.height);

    UIWindow *w = [[UIWindow alloc] initWithFrame:CGRectMake(0,0,W,H)];
    w.windowLevel = UIWindowLevelAlert + 100;
    w.backgroundColor = UIColor.clearColor;
    w.hidden = NO;

    self.frame = CGRectMake(0,0,W,H);
    _metalView.frame = self.bounds;
    ImGui::GetIO().DisplaySize = ImVec2(W * UIScreen.mainScreen.scale, H * UIScreen.mainScreen.scale);
    [w addSubview:self];

    objc_setAssociatedObject(UIApplication.sharedApplication, "xc_win", w, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self alog:[NSString stringWithFormat:@"start %.0fx%.0f", W, H]];

    [NSNotificationCenter.defaultCenter addObserver:self
        selector:@selector(rot:)
        name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)rot:(NSNotification*)n {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        CGRect r = UIScreen.mainScreen.bounds;
        CGFloat W = MAX(r.size.width, r.size.height);
        CGFloat H = MIN(r.size.width, r.size.height);
        UIWindow *win = objc_getAssociatedObject(UIApplication.sharedApplication, "xc_win");
        win.frame = CGRectMake(0,0,W,H);
        self.frame = CGRectMake(0,0,W,H);
        self->_metalView.frame = self.bounds;
        ImGui::GetIO().DisplaySize = ImVec2(W*UIScreen.mainScreen.scale, H*UIScreen.mainScreen.scale);
    });
}

- (void)alog:(NSString*)m {
    [_log addObject:[NSString stringWithFormat:@"[%@] %@",
        [NSDateFormatter localizedStringFromDate:NSDate.date dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle], m]];
    if (_log.count > 100) [_log removeObjectAtIndex:0];
}

#pragma mark - Touch

- (void)touchesBegan:(NSSet<UITouch*>*)ts withEvent:(UIEvent*)e { [self touch:ts down:YES]; }
- (void)touchesMoved:(NSSet<UITouch*>*)ts withEvent:(UIEvent*)e { [self touch:ts down:NO]; }
- (void)touchesEnded:(NSSet<UITouch*>*)ts withEvent:(UIEvent*)e { [self up:ts]; }
- (void)touchesCancelled:(NSSet<UITouch*>*)ts withEvent:(UIEvent*)e { [self up:ts]; }

- (void)touch:(NSSet<UITouch*>*)ts down:(BOOL)d {
    if (!_ready) return;
    CGPoint p = [ts.anyObject locationInView:self];
    p.x *= self.contentScaleFactor;
    p.y *= self.contentScaleFactor;
    ImGui::GetIO().AddMousePosEvent(p.x, p.y);
    if (d) ImGui::GetIO().AddMouseButtonEvent(0, true);
}

- (void)up:(NSSet<UITouch*>*)ts {
    if (!_ready) return;
    CGPoint p = [ts.anyObject locationInView:self];
    p.x *= self.contentScaleFactor;
    p.y *= self.contentScaleFactor;
    ImGui::GetIO().AddMousePosEvent(p.x, p.y);
    ImGui::GetIO().AddMouseButtonEvent(0, false);
}

#pragma mark - MTKView

- (void)mtkView:(MTKView*)v drawableSizeWillChange:(CGSize)s {
    if (!_ready) return;
    ImGui::GetIO().DisplaySize = ImVec2(s.width, s.height);
}

- (void)drawInMTKView:(MTKView*)v {
    if (!_ready) return;
    ImGui_ImplMetal_NewFrame(v.currentRenderPassDescriptor);
    ImGui::NewFrame();
    [self menu];
    ImGui::Render();
    ImDrawData *dd = ImGui::GetDrawData();
    if (!dd) return;
    MTLRenderPassDescriptor *rp = v.currentRenderPassDescriptor;
    if (!rp) return;
    id<MTLCommandBuffer> cb = [_commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> e = [cb renderCommandEncoderWithDescriptor:rp];
    ImGui_ImplMetal_RenderDrawData(dd, cb, e);
    [e endEncoding];
    [cb presentDrawable:v.currentDrawable];
    [cb commit];
}

#pragma mark - Menu

- (void)menu {
    if (!_visible) return;
    _fpsCount++;
    CFTimeInterval n = CACurrentMediaTime();
    if (n-_fpsTime>=FPS_REFRESH_INTERVAL) { _fps=_fpsCount/(n-_fpsTime); _fpsCount=0; _fpsTime=n; }

    float sw = ImGui::GetIO().DisplaySize.x;
    float sh = ImGui::GetIO().DisplaySize.y;
    if (sw<=0)sw=1024; if (sh<=0)sh=768;

    ImGui::SetNextWindowPos(ImVec2(10,10), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowBgAlpha(0.4f);
    ImGui::Begin("FPS",0, ImGuiWindowFlags_NoDecoration|ImGuiWindowFlags_AlwaysAutoResize|ImGuiWindowFlags_NoInputs|ImGuiWindowFlags_NoSavedSettings);
    ImGui::TextColored(ImVec4(0,1,0,1), "%.0f FPS  %.0fx%.0f", _fps, sw, sh);
    ImGui::End();

    if (_minimized) {
        ImGui::SetNextWindowPos(ImVec2(10,60), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowSize(ImVec2(220,48), ImGuiCond_Always);
        ImGui::Begin("##b",0, ImGuiWindowFlags_NoDecoration|ImGuiWindowFlags_NoResize|ImGuiWindowFlags_NoMove|ImGuiWindowFlags_NoSavedSettings);
        if (ImGui::Button("Open Menu", ImVec2(200,30))) _minimized=NO;
        ImGui::End();
        return;
    }

    float mw = sw*0.45f; if (mw<340) mw=340; if (mw>560) mw=560;
    float mh = sh*0.55f; if (mh<380) mh=380;

    ImGui::SetNextWindowSize(ImVec2(mw,mh), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowPos(ImVec2(20,60), ImGuiCond_FirstUseEver);

    if (!ImGui::Begin("iOS XC Tool", &_visible, ImGuiWindowFlags_NoResize)) { ImGui::End(); return; }

    if (ImGui::Button("_",ImVec2(36,0))) _minimized=YES;
    ImGui::SameLine(); ImGui::Text("v" APP_VERSION);
    ImGui::Separator();

    if (ImGui::BeginTabBar("t")) {
        if (ImGui::BeginTabItem("Home")) {
            ImGui::Text("Bundle: %s", NSBundle.mainBundle.bundleIdentifier.UTF8String ?: "?");
            ImGui::Text("Device: %s", UIDevice.currentDevice.model.UTF8String ?: "?");
            ImGui::Text("iOS:   %s", UIDevice.currentDevice.systemVersion.UTF8String ?: "?");
            ImGui::EndTabItem();
        }
        if (ImGui::BeginTabItem("Test")) {
            ImGui::Checkbox("Toggle", &_tb);
            ImGui::SliderFloat("Float", &_tf, 0, 100, "%.1f");
            ImGui::SliderInt("Int", &_ti, 0, 100);
            if (ImGui::Button("Click", ImVec2(-1,40))) { [self alog:@"Click"]; _ti++; }
            if (ImGui::Button("Reset", ImVec2(-1,40))) { _tf=50;_ti=42;_tb=NO; }
            ImGui::Text("B:%s F:%.1f I:%d", _tb?"Y":"N", _tf, _ti);
            ImGui::EndTabItem();
        }
        if (ImGui::BeginTabItem("Log")) {
            if (ImGui::SmallButton("Clear")) [_log removeAllObjects];
            ImGui::SameLine(); ImGui::Text("(%lu)", (unsigned long)_log.count);
            ImGui::Separator();
            ImGui::BeginChild("l", ImVec2(0,0), true);
            for (NSString *m in _log) ImGui::TextUnformatted(m.UTF8String);
            if (_log.count>0 && ImGui::GetScrollY()>=ImGui::GetScrollMaxY()) ImGui::SetScrollHereY(1);
            ImGui::EndChild();
            ImGui::EndTabItem();
        }
        ImGui::EndTabBar();
    }
    ImGui::End();
}

@end
