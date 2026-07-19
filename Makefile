# ios-xc-tool
# iOS dylib injection tool - ImGui overlay

SDK_PATH ?= $(shell xcrun --sdk iphoneos --show-sdk-path)
ARCH     ?= arm64
MIN_IOS  ?= 12.0
OUTPUT   ?= build/ios_xc_tool.dylib

SRC_DIR  = src
IMGUI_DIR = deps/imgui

CXX      = xcrun --sdk iphoneos clang++
CXXFLAGS = -arch $(ARCH) -isysroot $(SDK_PATH) -miphoneos-version-min=$(MIN_IOS)
CXXFLAGS += -I$(IMGUI_DIR) -I$(IMGUI_DIR)/backends -I$(SRC_DIR)
CXXFLAGS += -std=c++17 -fobjc-arc -O2 -fvisibility=hidden
LDFLAGS  = -shared -install_name @rpath/ios_xc_tool.dylib
LDFLAGS += -framework UIKit -framework Metal -framework MetalKit
LDFLAGS += -framework QuartzCore -framework Foundation -framework CoreGraphics

IMGUI_SRC  = $(IMGUI_DIR)/imgui.cpp
IMGUI_SRC += $(IMGUI_DIR)/imgui_draw.cpp
IMGUI_SRC += $(IMGUI_DIR)/imgui_widgets.cpp
IMGUI_SRC += $(IMGUI_DIR)/imgui_tables.cpp
IMGUI_SRC += $(IMGUI_DIR)/backends/imgui_impl_metal.mm

OUR_SRC  = $(SRC_DIR)/main.mm
OUR_SRC += $(SRC_DIR)/OverlayView.mm

OBJS = $(IMGUI_SRC:.cpp=.o) $(OUR_SRC:.mm=.o) $(IMGUI_SRC:.mm=.o)

.PHONY: all clean setup

all: $(OUTPUT)

setup:
	./setup.sh

$(OUTPUT): $(IMGUI_SRC) $(OUR_SRC)
	@mkdir -p build
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ $(IMGUI_SRC) $(OUR_SRC)
	@echo "[+] $(OUTPUT)"
	@ls -lh $(OUTPUT)

clean:
	rm -rf build

check:
	@which xcrun >/dev/null 2>&1 || (echo "[-] xcrun not found. Install Xcode." && exit 1)
	@echo "[+] SDK: $(SDK_PATH)"
