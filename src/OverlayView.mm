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

- (CGSize)screenSize {
    CGSize s = [UIScreen mainScreen].bounds.size;
    return s;
}

- (instancetype)init {
    CGSize sz = [self screenSize];
    self = [super initWithFrame:CGRectMake(0, 0, sz.width, sz.height)];
    if (self) {
        _menuVisible = YES;
        _menuMinimized = NO;
        _imguiReady = NO;
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

        _metalView = [[MTKView alloc] initWithFrame:self.bounds device:_device];
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

- (void)layoutSubviews {
    [super layoutSubviews];
    _metalView.frame = self.bounds;
}

- (void)initImGui {
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO &io = ImGui::GetIO();
    io.DisplaySize = ImVec2(self.bounds.size.width, self.bounds.size.height);

    // Touch-friendly settings
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;

    ImGui::StyleColorsDark();
    ImGuiStyle &style = ImGui::GetStyle();
    style.ScaleAllSizes(1.5f);

    ImFontConfig fontCfg;
    fontCfg.SizePixels = 18.0f;
    io.Fonts->AddFontDefault(&fontCfg);

    ImGui_ImplMetal_Init(_device);

    _imguiReady = YES;
    [self addLog:[NSString stringWithFormat:@"Screen: %.0fx%.0f", self.bounds.size.width, self.bounds.size.height]];
}

- (void)show {
    UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    window.windowLevel = OVERLAY_WINDOW_LEVEL;
    window.backgroundColor = [UIColor clearColor];
    window.hidden = NO;

    self.frame = window.bounds;
    _metalView.frame = self.bounds;

    ImGuiIO &io = ImGui::GetIO();
    io.DisplaySize = ImVec2(self.bounds.size.width, self.bounds.size.height);

    [window addSubview:self];
    objc_setAssociatedObject([UIApplication sharedApplication],
                             "ios_xc_tool_window",
                             window,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Observe rotation
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(orientationChanged:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
}

- (void)orientationChanged:(NSNotification *)note {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIWindow *w = objc_getAssociatedObject([UIApplication sharedApplication], "ios_xc_tool_window");
        self.frame = [UIScreen mainScreen].bounds;
        w.frame = self.frame;
        self->_metalView.frame = self.bounds;
        ImGuiIO &io = ImGui::GetIO();
        io.DisplaySize = ImVec2(self.bounds.size.width, self.bounds.size.height);
    });
}

- (void)addLog:(NSString *)msg {
    [_logMessages addObject:[NSString stringWithFormat:@"[%@] %@",
                             [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                            dateStyle:NSDateFormatterNoStyle
                                                            timeStyle:NSDateFormatterMediumStyle],
                             msg]];
    if (_logMessages.count > 100) [_logMessages removeObjectAtIndex:0];
}

#pragma mark - Touch forwarding to ImGui

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (!_imguiReady) return NO;
    ImGuiIO &io = ImGui::GetIO();
    return io.WantCaptureMouse || io.WantCaptureKeyboard;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self forwardTouches:touches phase:ImGuiMouseButton_Left down:YES];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self forwardTouches:touches phase:ImGuiMouseButton_Left down:NO];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self forwardTouchesUp:touches];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self forwardTouchesUp:touches];
}

- (void)forwardTouches:(NSSet<UITouch *> *)touches phase:(ImGuiMouseButton)button down:(BOOL)down {
    UITouch *t = [touches anyObject];
    CGPoint pt = [t locationInView:self];
    ImGuiIO &io = ImGui::GetIO();
    io.AddMousePosEvent(pt.x, pt.y);
    if (down) io.AddMouseButtonEvent(0, true);
}

- (void)forwardTouchesUp:(NSSet<UITouch *> *)touches {
    UITouch *t = [touches anyObject];
    CGPoint pt = [t locationInView:self];
    ImGuiIO &io = ImGui::GetIO();
    io.AddMousePosEvent(pt.x, pt.y);
    io.AddMouseButtonEvent(0, false);
}

#pragma mark - MTKViewDelegate

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    ImGuiIO &io = ImGui::GetIO();
    io.DisplaySize = ImVec2(size.width, size.height);
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

#pragma mark - Menu Rendering

- (void)renderMenu {
    if (!_menuVisible) return;

    // FPS Counter
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
            ImGuiWindowFlags_NoDecoration |
            ImGuiWindowFlags_AlwaysAutoResize |
            ImGuiWindowFlags_NoInputs);
        ImGui::Text("FPS: %.1f", _fps);
        ImGui::End();
    }

    // Minimized bar (show when collapsed)
    if (_menuMinimized) {
        ImGui::SetNextWindowPos(ImVec2(10, 60), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowSize(ImVec2(200, 40), ImGuiCond_Always);
        ImGui::Begin("##minibar", nullptr,
            ImGuiWindowFlags_NoDecoration |
            ImGuiWindowFlags_NoResize |
            ImGuiWindowFlags_NoMove |
            ImGuiWindowFlags_NoSavedSettings);
        ImGui::SetCursorPosX(10);
        if (ImGui::Button("Show Menu", ImVec2(180, 0))) {
            _menuMinimized = NO;
        }
        ImGui::End();
        return;
    }

    // Main Menu
    {
        float w = self.bounds.size.width;
        float h = self.bounds.size.height;
        float mw = w * 0.45f;
        float mh = h * 0.55f;
        if (mw < 350) mw = 350;
        if (mw > 600) mw = 600;
        if (mh < 350) mh = 350;

        ImGui::SetNextWindowSize(ImVec2(mw, mh), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowPos(ImVec2(20, 60), ImGuiCond_FirstUseEver);

        ImGui::Begin("iOS XC Tool", nullptr,
            ImGuiWindowFlags_NoResize);

        if (ImGui::Button("_")) _menuMinimized = YES;
        ImGui::SameLine();
        if (ImGui::Button("X")) _menuVisible = NO;
        ImGui::SameLine();
        ImGui::Text("v" APP_VERSION "  |  %.0fx%.0f", w, h);

        ImGui::Separator();

        if (ImGui::BeginTabBar("MainTabs")) {

            if (ImGui::BeginTabItem("Home")) {
                ImGui::TextWrapped("Welcome to iOS XC Tool!");
                ImGui::Separator();
                ImGui::Text("Bundle: %s", [[[NSBundle mainBundle] bundleIdentifier] UTF8String] ?: "?");
                ImGui::Text("Device: %s", [[[UIDevice currentDevice] model] UTF8String] ?: "?");
                ImGui::Text("iOS: %s", [[[UIDevice currentDevice] systemVersion] UTF8String] ?: "?");
                ImGui::Text("Screen: %.0fx%.0f", w, h);
                ImGui::EndTabItem();
            }

            if (ImGui::BeginTabItem("Test")) {
                ImGui::Checkbox("Toggle me", &_testBool);
                ImGui::SliderFloat("Float", &_testFloat, 0.0f, 100.0f, "%.1f");
                ImGui::SliderInt("Int", &_testInt, 0, 100);

                if (ImGui::Button("Click me", ImVec2(120, 0))) {
                    [self addLog:@"Button clicked!"];
                    _testInt++;
                }
                ImGui::SameLine();
                if (ImGui::Button("Reset", ImVec2(120, 0))) {
                    _testFloat = 50.0f;
                    _testInt = 42;
                    _testBool = NO;
                }
                ImGui::Text("Bool: %s  Float: %.1f  Int: %d",
                    _testBool ? "YES" : "NO", _testFloat, _testInt);
                ImGui::EndTabItem();
            }

            if (ImGui::BeginTabItem("Log")) {
                ImGui::Text("Log (%lu)", (unsigned long)_logMessages.count);
                ImGui::SameLine();
                if (ImGui::SmallButton("Clear")) [_logMessages removeAllObjects];
                ImGui::Separator();
                ImGui::BeginChild("LogScroller", ImVec2(0, 0), true);
                for (NSString *msg in _logMessages) {
                    ImGui::TextUnformatted([msg UTF8String]);
                }
                if (_logMessages.count > 0 && ImGui::GetScrollY() >= ImGui::GetScrollMaxY())
                    ImGui::SetScrollHereY(1.0f);
                ImGui::EndChild();
                ImGui::EndTabItem();
            }

            if (ImGui::BeginTabItem("About")) {
                ImGui::Text("iOS XC Tool v" APP_VERSION);
                ImGui::Separator();
                ImGui::Text("ImGui v" IMGUI_VERSION " + Metal");
                ImGui::Separator();
                ImGui::TextWrapped("Injects into any iOS app at runtime.");
                ImGui::EndTabItem();
            }

            ImGui::EndTabBar();
        }

        ImGui::End();
    }
}

@end
