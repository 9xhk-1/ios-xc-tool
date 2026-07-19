#import "OverlayView.h"
#import "Config.h"
#import "imgui.h"
#import "imgui_impl_metal.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface OverlayView ()
@property (nonatomic, assign) BOOL menuVisible;
@property (nonatomic, assign) BOOL imguiReady;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, assign) float fps;
@property (nonatomic, assign) CFTimeInterval lastFpsTime;
@property (nonatomic, assign) int frameCount;
@property (nonatomic, assign) BOOL testBool;
@property (nonatomic, assign) float testFloat;
@property (nonatomic, assign) int testInt;
@property (nonatomic, strong) NSMutableArray *logMessages;
@property (nonatomic, assign) BOOL menuMinimized;
@property (nonatomic, assign) BOOL touchDown;
@end

@implementation OverlayView

+ (instancetype)shared {
    static OverlayView *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[OverlayView alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _menuVisible = YES;
        _menuMinimized = NO;
        _imguiReady = NO;
        _touchDown = NO;
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

        _device = MTLCreateSystemDefaultDevice();
        if (!_device) return self;

        _commandQueue = [_device newCommandQueue];

        CGRect screenRect = [UIScreen mainScreen].bounds;
        _metalView = [[MTKView alloc] initWithFrame:screenRect device:_device];
        _metalView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _metalView.backgroundColor = [UIColor clearColor];
        _metalView.delegate = self;
        _metalView.framebufferOnly = NO;
        _metalView.clearColor = MTLClearColorMake(0, 0, 0, 0);
        _metalView.paused = NO;
        _metalView.enableSetNeedsDisplay = NO;

        [self addSubview:_metalView];

        [self initImGui];
    }
    return self;
}

- (void)initImGui {
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();

    // Disable ini file (dylib has no writable dir)
    ImGui::GetIO().IniFilename = NULL;

    ImGuiIO &io = ImGui::GetIO();
    io.DisplaySize = ImVec2(_metalView.drawableSize.width, _metalView.drawableSize.height);
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;

    ImGui::StyleColorsDark();
    ImGuiStyle &style = ImGui::GetStyle();
    style.ScaleAllSizes(1.5f);
    style.WindowRounding = 4.0f;
    style.FrameRounding = 3.0f;

    ImFontConfig fontCfg;
    fontCfg.SizePixels = 18.0f;
    io.Fonts->AddFontDefault(&fontCfg);

    ImGui_ImplMetal_Init(_device);

    _imguiReady = YES;
    [self addLog:[NSString stringWithFormat:@"Init: %.0fx%.0f drawable:%.0fx%.0f",
        self.bounds.size.width, self.bounds.size.height,
        _metalView.drawableSize.width, _metalView.drawableSize.height]];
}

- (void)show {
    CGRect screen = [UIScreen mainScreen].bounds;
    UIWindow *window = [[UIWindow alloc] initWithFrame:screen];
    window.windowLevel = OVERLAY_WINDOW_LEVEL;
    window.backgroundColor = [UIColor clearColor];
    window.hidden = NO;
    window.userInteractionEnabled = YES;

    self.frame = screen;
    _metalView.frame = self.bounds;

    ImGuiIO &io = ImGui::GetIO();
    io.DisplaySize = ImVec2(_metalView.drawableSize.width, _metalView.drawableSize.height);

    [window addSubview:self];
    objc_setAssociatedObject([UIApplication sharedApplication],
                             "ios_xc_tool_window",
                             window,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(orientationChanged:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];

    [self addLog:[NSString stringWithFormat:@"Window: %.0fx%.0f", screen.size.width, screen.size.height]];
}

- (void)orientationChanged:(NSNotification *)note {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIWindow *w = objc_getAssociatedObject([UIApplication sharedApplication], "ios_xc_tool_window");
        CGRect s = [UIScreen mainScreen].bounds;
        self.frame = s;
        w.frame = s;
        self->_metalView.frame = self.bounds;
        ImGuiIO &io = ImGui::GetIO();
        io.DisplaySize = ImVec2(self->_metalView.drawableSize.width, self->_metalView.drawableSize.height);
    });
}

- (void)addLog:(NSString *)msg {
    [_logMessages addObject:[NSString stringWithFormat:@"[%@] %@",
        [NSDateFormatter localizedStringFromDate:[NSDate date]
                                       dateStyle:NSDateFormatterNoStyle
                                       timeStyle:NSDateFormatterMediumStyle], msg]];
    if (_logMessages.count > 100) [_logMessages removeObjectAtIndex:0];
}

#pragma mark - Touch forwarding

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    _touchDown = YES;
    UITouch *t = [touches anyObject];
    CGPoint pt = [t locationInView:self];
    ImGui::GetIO().AddMousePosEvent(pt.x, pt.y);
    ImGui::GetIO().AddMouseButtonEvent(0, true);
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *t = [touches anyObject];
    CGPoint pt = [t locationInView:self];
    ImGui::GetIO().AddMousePosEvent(pt.x, pt.y);
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    _touchDown = NO;
    UITouch *t = [touches anyObject];
    CGPoint pt = [t locationInView:self];
    ImGui::GetIO().AddMousePosEvent(pt.x, pt.y);
    ImGui::GetIO().AddMouseButtonEvent(0, false);
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    _touchDown = NO;
    ImGui::GetIO().AddMouseButtonEvent(0, false);
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    // Always return self so touches reach our methods, no deeper view
    return self;
}

#pragma mark - MTKViewDelegate

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    ImGui::GetIO().DisplaySize = ImVec2(size.width, size.height);
}

- (void)drawInMTKView:(MTKView *)view {
    if (!_imguiReady) return;

    ImGui_ImplMetal_NewFrame(view.currentRenderPassDescriptor);
    ImGui::NewFrame();

    [self renderMenu];

    ImGui::Render();
    ImDrawData *drawData = ImGui::GetDrawData();
    if (!drawData) return;

    MTLRenderPassDescriptor *rpDesc = view.currentRenderPassDescriptor;
    if (!rpDesc) return;

    id<MTLCommandBuffer> cmdBuf = [_commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [cmdBuf renderCommandEncoderWithDescriptor:rpDesc];

    ImGui_ImplMetal_RenderDrawData(drawData, cmdBuf, encoder);

    [encoder endEncoding];
    [cmdBuf presentDrawable:view.currentDrawable];
    [cmdBuf commit];
}

#pragma mark - Menu

- (void)renderMenu {
    if (!_menuVisible) return;

    float sw = _metalView.drawableSize.width;
    float sh = _metalView.drawableSize.height;

    // FPS
    {
        _frameCount++;
        CFTimeInterval now = CACurrentMediaTime();
        if (now - _lastFpsTime >= FPS_REFRESH_INTERVAL) {
            _fps = _frameCount / (now - _lastFpsTime);
            _frameCount = 0;
            _lastFpsTime = now;
        }
        ImGui::SetNextWindowPos(ImVec2(10, 10), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowBgAlpha(0.5f);
        ImGui::Begin("FPS", nullptr,
            ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoInputs);
        ImGui::Text("FPS: %.1f  %.0fx%.0f", _fps, sw, sh);
        ImGui::End();
    }

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

    float mw = sw * 0.45f;
    float mh = sh * 0.60f;
    if (mw < 340) mw = 340;
    if (mw > 560) mw = 560;
    if (mh < 380) mh = 380;

    ImGui::SetNextWindowSize(ImVec2(mw, mh), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowPos(ImVec2(20, 60), ImGuiCond_FirstUseEver);

    ImGui::Begin("iOS XC Tool", nullptr, ImGuiWindowFlags_NoResize);

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
            ImGui::Text("Screen: %.0fx%.0f", sw, sh);
            ImGui::EndTabItem();
        }

        if (ImGui::BeginTabItem("Test")) {
            ImGui::Checkbox("Toggle", &_testBool);
            ImGui::SliderFloat("Float", &_testFloat, 0.0f, 100.0f, "%.1f");
            ImGui::SliderInt("Int", &_testInt, 0, 100);
            if (ImGui::Button("Click me", ImVec2(-1, 40))) {
                [self addLog:@"Clicked"]; _testInt++;
            }
            if (ImGui::Button("Reset", ImVec2(-1, 40))) {
                _testFloat = 50.0f; _testInt = 42; _testBool = NO;
            }
            ImGui::Text("Bool:%s  Float:%.1f  Int:%d", _testBool?"yes":"no", _testFloat, _testInt);
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
