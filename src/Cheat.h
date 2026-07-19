#pragma once
#include <mach/mach.h>
extern bool gAutoShoot;
extern float gAimSpeed;
extern float gFovRadius;
namespace MemX { extern mach_port_t gTask; bool Init(pid_t pid); }
void CheatTick();
