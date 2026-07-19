#import "OverlayView.h"
#import "Config.h"
#import "imgui.h"
#import "imgui_impl_metal.h"
#import <UIKit/UIKit.h>

@interface OverlayView ()
@property (nonatomic, assign) BOOL menuVisible;
@property (nonatomic, assign) BOOL imguiReady;
@property (nonatomic, assign) float fps;
@property (nonatomic, assign) CFTimeInterval lastFpsTime;
@property (nonatomic, assign) int frameCount;
@property (nonatomic, assign) BOOL testBool;
@property (nonatomic, assign) float testFloat;
@property (nonatomic, assign) int testInt;
@property (nonatomic, strong) NSMutableArray *logMessages;
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
    self = [super initWithFrame:[UIScreen mainScreen].bounds];
    if (self) {
        _menuVisible = YES;
        _imguiReady = NO;
        _testBool = NO;
        _testFloat = 50.0f;
        _testInt = 42;
        _fps = 0.0f;
        _lastFpsTime = 0;
        _frameCount = 0;
        _logMessages = [NSMutableArray array];

        self.backgroundColor = [UIColor clearColor];

        _device = MTLCreateSystemDefaultDevice();
        if (!_device) return self;

        _metalView = [[MTKView alloc] initWithFrame:self.bounds device:_device];
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
    ImGuiIO &io = ImGui::GetIO();
    io.DisplaySize = ImVec2(self.bounds.size.width, self.bounds.size.height);

    ImGui::StyleColorsDark();

    ImGui_ImplMetal_Init(_device);

    _imguiReady = YES;
    [self addLog:@"ImGui + Metal initialized OK"];
}

- (void)show {
    UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    window.windowLevel = OVERLAY_WINDOW_LEVEL;
    window.backgroundColor = [UIColor clearColor];
    window.hidden = NO;

    self.frame = window.bounds;
    _metalView.frame = self.bounds;

    [window addSubview:self];
    objc_setAssociatedObject([UIApplication sharedApplication],
                             "ios_xc_tool_window",
                             window,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)hide {
    UIWindow *window = objc_getAssociatedObject([UIApplication sharedApplication], "ios_xc_tool_window");
    window.hidden = YES;
}

- (void)toggle {
    UIWindow *window = objc_getAssociatedObject([UIApplication sharedApplication], "ios_xc_tool_window");
    window.hidden = !window.hidden;
}

- (void)addLog:(NSString *)msg {
    [_logMessages addObject:[NSString stringWithFormat:@"[%@] %@",
                             [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                            dateStyle:NSDateFormatterNoStyle
                                                            timeStyle:NSDateFormatterMediumStyle],
                             msg]];
    if (_logMessages.count > 100) [_logMessages removeObjectAtIndex:0];
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
    if (drawData) {
        id<MTLCommandBuffer> cmdBuf = [view.currentRenderPassDescriptor.colorAttachments[0].texture
                                       newTextureViewWithPixelFormat:MTLPixelFormatBGRA8Unorm].newTextureView;
        ImGui_ImplMetal_RenderDrawData(drawData,
            (__bridge id<MTLCommandBuffer>)(__bridge void *)view.currentRenderPassDescriptor,
            (__bridge id<MTLRenderCommandEncoder>)(__bridge void *)view.currentRenderPassDescriptor);
    }
}

#pragma mark - Menu Rendering

- (void)renderMenu {
    if (!_menuVisible) return;

    // ---- FPS Counter ----
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
        ImGui::TextColored(ImVec4(0.0f, 1.0f, 0.0f, 1.0f), "%.1f FPS", _fps);
        ImGui::End();
    }

    // ---- Main Menu ----
    {
        ImGui::SetNextWindowSize(ImVec2(MENU_WIDTH, MENU_HEIGHT), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowPos(ImVec2(MENU_POS_X, MENU_POS_Y), ImGuiCond_FirstUseEver);

        ImGui::Begin("iOS XC Tool v" APP_VERSION, &_menuVisible);

        if (ImGui::BeginTabBar("MainTabs")) {

            // --- Tab: Home ---
            if (ImGui::BeginTabItem("Home")) {
                ImGui::TextWrapped("Welcome to iOS XC Tool !");
                ImGui::Separator();
                ImGui::Text("App name: %s", [[[NSBundle mainBundle] bundleIdentifier] UTF8String] ?: "unknown");
                ImGui::Text("Device: %s", [[[UIDevice currentDevice] model] UTF8String] ?: "unknown");
                ImGui::Text("iOS: %s", [[[UIDevice currentDevice] systemVersion] UTF8String] ?: "unknown");
                ImGui::EndTabItem();
            }

            // --- Tab: Test ---
            if (ImGui::BeginTabItem("Test")) {
                ImGui::Text("This is the Test tab");
                ImGui::Separator();

                ImGui::Checkbox("Toggle me", &_testBool);
                ImGui::SliderFloat("Float slider", &_testFloat, 0.0f, 100.0f, "%.1f");
                ImGui::SliderInt("Int slider", &_testInt, 0, 100);

                if (ImGui::Button("Click me")) {
                    [self addLog:@"Button clicked!"];
                    _testInt++;
                }

                ImGui::SameLine();
                if (ImGui::Button("Reset")) {
                    _testFloat = 50.0f;
                    _testInt = 42;
                    _testBool = NO;
                    [self addLog:@"Values reset"];
                }

                ImGui::Text("Bool: %s, Float: %.1f, Int: %d",
                    _testBool ? "YES" : "NO", _testFloat, _testInt);

                ImGui::EndTabItem();
            }

            // --- Tab: Log ---
            if (ImGui::BeginTabItem("Log")) {
                ImGui::Text("Log messages (%lu)", (unsigned long)_logMessages.count);
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

            // --- Tab: About ---
            if (ImGui::BeginTabItem("About")) {
                ImGui::Text("iOS XC Tool");
                ImGui::Text("Version: " APP_VERSION);
                ImGui::Separator();
                ImGui::Text("Based on Dear ImGui v" IMGUI_VERSION);
                ImGui::Text("Rendering: Metal");
                ImGui::Separator();
                ImGui::TextWrapped("Injects an ImGui overlay into iOS apps.\n"
                                   "Use as framework replacement or DYLD_INSERT_LIBRARIES.");
                ImGui::EndTabItem();
            }

            ImGui::EndTabBar();
        }

        ImGui::End();
    }
}

@end
