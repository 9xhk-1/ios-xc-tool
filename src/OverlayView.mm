#import "OverlayView.h"
#import "Config.h"
#import "imgui.h"
#import "imgui_impl_metal.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// hitTest safe: never calls ImGui before context is ready
@interface OverlayWindow : UIWindow
@property (nonatomic, weak) OverlayView *overlayView;
@end
@implementation OverlayWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self || hit == self.overlayView || hit == self.overlayView.metalView) {
        if (!self.overlayView.isReady) return nil;
        if (ImGui::GetCurrentContext() != NULL && ImGui::GetIO().WantCaptureMouse)
            return self.overlayView;
        return nil;
    }
    return nil;
}
@end

@interface OverlayView ()
@property (nonatomic, assign) BOOL menuVisible;
@property (nonatomic, assign) BOOL menuMinimized;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, assign) float fps;
@property (nonatomic, assign) CFTimeInterval lastFpsTime;
@property (nonatomic, assign) int frameCount;
@property (nonatomic, assign) BOOL testBool;
@property (nonatomic, assign) float testFloat;
@property (nonatomic, assign) int testInt;
@property (nonatomic, strong) NSMutableArray *logMessages;
@end

@implementation OverlayView

@synthesize isReady = _isReady;

+ (instancetype)shared {
    static OverlayView *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[OverlayView alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _menuVisible = YES;
        _menuMinimized = NO;
        _isReady = NO;
        _testBool = NO;
        _testFloat = 50.0f;
        _testInt = 42;
        _fps = 0.0f;
        _lastFpsTime = 0;
        _frameCount = 0;
        _logMessages = [NSMutableArray array];

        self.backgroundColor = [UIColor clearColor];
        self.multipleTouchEnabled = NO;
        self.userInteractionEnabled = YES;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        _device = MTLCreateSystemDefaultDevice();
        if (!_device) return self;

        _commandQueue = [_device newCommandQueue];

        _metalView = [[MTKView alloc] initWithFrame:CGRectZero device:_device];
        _metalView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _metalView.backgroundColor = [UIColor clearColor];
        _metalView.delegate = self;
        _metalView.framebufferOnly = NO;
        _metalView.clearColor = MTLClearColorMake(0, 0, 0, 0);
        _metalView.paused = NO;
        _metalView.enableSetNeedsDisplay = NO;
        _metalView.userInteractionEnabled = NO;
        [self addSubview:_metalView];
    }
    return self;
}

- (void)setupImGuiAndMetal {
    // Must be called on main thread — GImGui is thread_local
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGui::GetIO().IniFilename = NULL;
    ImGui::GetIO().ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;

    ImGui::StyleColorsDark();
    ImGuiStyle &style = ImGui::GetStyle();
    style.ScaleAllSizes(1.5f);
    style.WindowRounding = 4.0f;
    style.FrameRounding = 3.0f;
    style.WindowTitleAlign = ImVec2(0.5f, 0.5f);

    ImFontConfig fontCfg;
    fontCfg.SizePixels = 18.0f;
    ImGui::GetIO().Fonts->AddFontDefault(&fontCfg);

    ImGui_ImplMetal_Init(_device);
    _isReady = YES;
}

- (void)show {
    // Force landscape — UIScreen.bounds is always portrait on iPad
    CGRect screen = [UIScreen mainScreen].bounds;
    CGFloat w = MAX(screen.size.width, screen.size.height);
    CGFloat h = MIN(screen.size.width, screen.size.height);
    CGRect landscape = CGRectMake(0, 0, w, h);

    OverlayWindow *window = [[OverlayWindow alloc] initWithFrame:landscape];
    window.overlayView = self;
    window.windowLevel = UIWindowLevelAlert + 100;
    window.backgroundColor = [UIColor clearColor];
    window.hidden = NO;

    self.frame = landscape;
    _metalView.frame = landscape;
    ImGui::GetIO().DisplaySize = ImVec2(w, h);

    [window addSubview:self];
    objc_setAssociatedObject([UIApplication sharedApplication],
                             "xc_overlay", window, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [self addLog:[NSString stringWithFormat:@"Screen %.0fx%.0f", w, h]];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(orientationChanged:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
}

- (void)orientationChanged:(NSNotification *)note {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{
        CGRect s = [UIScreen mainScreen].bounds;
        CGFloat w = MAX(s.size.width, s.size.height);
        CGFloat h = MIN(s.size.width, s.size.height);
        CGRect f = CGRectMake(0, 0, w, h);
        OverlayWindow *win = objc_getAssociatedObject([UIApplication sharedApplication], "xc_overlay");
        win.frame = f;
        self.frame = f;
        self->_metalView.frame = f;
        ImGui::GetIO().DisplaySize = ImVec2(w, h);
        [self addLog:[NSString stringWithFormat:@"Rotate %.0fx%.0f", w, h]];
    });
}

- (void)addLog:(NSString *)msg {
    [_logMessages addObject:[NSString stringWithFormat:@"%@ %@",
        [NSDateFormatter localizedStringFromDate:[NSDate date]
                                       dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle], msg]];
    if (_logMessages.count > 100) [_logMessages removeObjectAtIndex:0];
}

#pragma mark - Touch (always safe due to _isReady guard)

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!_isReady) return;
    CGPoint pt = [[touches anyObject] locationInView:self];
    ImGui::GetIO().AddMousePosEvent(pt.x, pt.y);
    ImGui::GetIO().AddMouseButtonEvent(0, true);
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!_isReady) return;
    CGPoint pt = [[touches anyObject] locationInView:self];
    ImGui::GetIO().AddMousePosEvent(pt.x, pt.y);
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!_isReady) return;
    CGPoint pt = [[touches anyObject] locationInView:self];
    ImGui::GetIO().AddMousePosEvent(pt.x, pt.y);
    ImGui::GetIO().AddMouseButtonEvent(0, false);
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!_isReady) return;
    ImGui::GetIO().AddMouseButtonEvent(0, false);
}

#pragma mark - MTKViewDelegate

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    if (!_isReady) return;
    ImGui::GetIO().DisplaySize = ImVec2(size.width, size.height);
}

- (void)drawInMTKView:(MTKView *)view {
    if (!_isReady) return;

    ImGui_ImplMetal_NewFrame(view.currentRenderPassDescriptor);
    ImGui::NewFrame();
    [self renderMenu];
    ImGui::Render();

    ImDrawData *dd = ImGui::GetDrawData();
    if (!dd) return;

    MTLRenderPassDescriptor *rp = view.currentRenderPassDescriptor;
    if (!rp) return;

    id<MTLCommandBuffer> cb = [_commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> enc = [cb renderCommandEncoderWithDescriptor:rp];
    ImGui_ImplMetal_RenderDrawData(dd, cb, enc);
    [enc endEncoding];
    [cb presentDrawable:view.currentDrawable];
    [cb commit];
}

#pragma mark - Menu

- (void)renderMenu {
    if (!_menuVisible) return;

    float sw = _metalView.drawableSize.width;
    float sh = _metalView.drawableSize.height;
    if (sw <= 0) sw = self.bounds.size.width;
    if (sh <= 0) sh = self.bounds.size.height;

    _frameCount++;
    CFTimeInterval now = CACurrentMediaTime();
    if (now - _lastFpsTime >= FPS_REFRESH_INTERVAL) {
        _fps = _frameCount / (now - _lastFpsTime);
        _frameCount = 0;
        _lastFpsTime = now;
    }

    // FPS counter
    ImGui::SetNextWindowPos(ImVec2(10, 10), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowBgAlpha(0.45f);
    ImGui::Begin("fps", nullptr,
        ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoInputs);
    ImGui::TextColored(ImVec4(0, 1, 0, 1), "%.0f FPS  %.0fx%.0f", _fps, sw, sh);
    ImGui::End();

    // Minimized bar
    if (_menuMinimized) {
        ImGui::SetNextWindowPos(ImVec2(10, 60), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowSize(ImVec2(220, 48), ImGuiCond_Always);
        ImGui::Begin("##bar", nullptr,
            ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoResize |
            ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoSavedSettings);
        if (ImGui::Button("Show Menu", ImVec2(200, 30))) _menuMinimized = NO;
        ImGui::End();
        return;
    }

    // Dynamic menu size
    float mw = sw * 0.45f;
    float mh = sh * 0.55f;
    if (mw < 340) mw = 340;
    if (mw > 560) mw = 560;
    if (mh < 380) mh = 380;

    ImGui::SetNextWindowSize(ImVec2(mw, mh), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowPos(ImVec2(20, 60), ImGuiCond_FirstUseEver);

    ImGui::Begin("iOS XC Tool", nullptr, 0);

    if (ImGui::Button("_", ImVec2(36, 0))) _menuMinimized = YES;
    ImGui::SameLine();
    if (ImGui::Button("X", ImVec2(36, 0))) _menuVisible = NO;
    ImGui::SameLine();
    ImGui::Text("v" APP_VERSION);
    ImGui::Separator();

    if (ImGui::BeginTabBar("tabs")) {

        if (ImGui::BeginTabItem("Home")) {
            ImGui::Text("Bundle: %s", [[[NSBundle mainBundle] bundleIdentifier] UTF8String] ?: "?");
            ImGui::Text("Device: %s", [[[UIDevice currentDevice] model] UTF8String] ?: "?");
            ImGui::Text("iOS:   %s", [[[UIDevice currentDevice] systemVersion] UTF8String] ?: "?");
            ImGui::EndTabItem();
        }

        if (ImGui::BeginTabItem("Test")) {
            ImGui::Checkbox("Toggle", &_testBool);
            ImGui::SliderFloat("Float", &_testFloat, 0.0f, 100.0f, "%.1f");
            ImGui::SliderInt("Int", &_testInt, 0, 100);
            if (ImGui::Button("Click", ImVec2(-1, 40))) { [self addLog:@"Click"]; _testInt++; }
            if (ImGui::Button("Reset", ImVec2(-1, 40))) { _testFloat = 50; _testInt = 42; _testBool = NO; }
            ImGui::Text("B:%s F:%.1f I:%d", _testBool ? "Y" : "N", _testFloat, _testInt);
            ImGui::EndTabItem();
        }

        if (ImGui::BeginTabItem("Log")) {
            if (ImGui::SmallButton("Clear")) [_logMessages removeAllObjects];
            ImGui::SameLine(); ImGui::Text("(%lu)", (unsigned long)_logMessages.count);
            ImGui::Separator();
            ImGui::BeginChild("log", ImVec2(0, 0), true);
            for (NSString *m in _logMessages) ImGui::TextUnformatted([m UTF8String]);
            if (_logMessages.count > 0 && ImGui::GetScrollY() >= ImGui::GetScrollMaxY())
                ImGui::SetScrollHereY(1.0f);
            ImGui::EndChild();
            ImGui::EndTabItem();
        }

        if (ImGui::BeginTabItem("About")) {
            ImGui::Text("iOS XC Tool v" APP_VERSION);
            ImGui::Text("ImGui " IMGUI_VERSION " + Metal");
            ImGui::EndTabItem();
        }

        ImGui::EndTabBar();
    }
    ImGui::End();
}

@end
