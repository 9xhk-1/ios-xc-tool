#include "Cheat.h"
#include <mach/mach.h>
#include <mach-o/dyld_images.h>
mach_port_t MemX::gTask=0; bool MemX::Init(pid_t p){return task_for_pid(mach_task_self(),p,&gTask)==KERN_SUCCESS;}
bool gAutoShoot=false; float gAimSpeed=5,gFovRadius=120; static bool gMod=false; static uint64_t gBase=0,gActor=0;
template<typename T> static T Read(uint64_t a){T v{};vm_size_t s=sizeof(T);vm_read_overwrite(MemX::gTask,a,sizeof(T),(vm_address_t)&v,&s);return v;}
template<typename T> static void Write(uint64_t a,T v){vm_write(MemX::gTask,a,(vm_address_t)&v,sizeof(T));}
static bool Ok(uint64_t a){return a>0x100000000&&a<0x200000000;}
static uint64_t FindBase(){
    task_dyld_info_data_t d;mach_msg_type_number_t n=TASK_DYLD_INFO_COUNT;
    if(task_info(mach_task_self_,TASK_DYLD_INFO,(task_info_t)&d,&n)!=0)return 0;
    uint64_t p=d.all_image_info_addr;if(!Ok(p))return 0;
    uint32_t c=Read<uint32_t>(p+8);uint64_t a=Read<uint64_t>(p+16);if(!Ok(a))return 0;
    for(uint32_t i=0;i<c&&i<256;i++){uint64_t e=a+i*24;uint64_t pp=Read<uint64_t>(e);
        if(!Ok(pp))continue;char b[256]={};vm_size_t z=255;
        vm_read_overwrite(MemX::gTask,pp,255,(vm_address_t)b,&z);
        if(strstr(b,"Sausage")||strstr(b,"Unity")||strstr(b,"il2cpp"))return Read<uint64_t>(e+16);}
    return 0;}
void CheatTick(){
    if(!gAutoShoot){if(gMod&&gActor){uint64_t c1=Read<uint64_t>(gActor+0x708);
        if(Ok(c1)){uint64_t c2=Read<uint64_t>(c1+0x20);if(Ok(c2)){uint64_t c3=Read<uint64_t>(c2+0x40);
        if(Ok(c3))Write<int>(c3+0x18,1055286886);}}gMod=false;}return;}
    if(MemX::gTask==MACH_PORT_NULL){MemX::Init(getpid());if(MemX::gTask==MACH_PORT_NULL)return;}
    if(!gBase){gBase=FindBase();if(!gBase)return;}
    if(!gActor){uint64_t gw=0;
        for(uint64_t o=0;o<0x400000;o+=8){uint64_t v=Read<uint64_t>(gBase+o);
            if(Ok(v)){uint64_t t=Read<uint64_t>(v+0x30);if(Ok(t)){gw=v;break;}}}
        if(!Ok(gw))return;
        uint64_t l=Read<uint64_t>(gw+0x30);if(!Ok(l))return;
        uint64_t gs=Read<uint64_t>(l+0x498);if(!Ok(gs))return;
        uint64_t pa=Read<uint64_t>(gs+0x2D0);if(!Ok(pa))return;
        uint64_t p0=Read<uint64_t>(pa);if(!Ok(p0))return;
        gActor=Read<uint64_t>(p0+0x20);}
    if(!Ok(gActor)){gActor=0;return;}
    uint64_t c1=Read<uint64_t>(gActor+0x708);if(!Ok(c1))return;
    uint64_t c2=Read<uint64_t>(c1+0x20);if(!Ok(c2))return;
    uint64_t c3=Read<uint64_t>(c2+0x40);if(!Ok(c3))return;
    int r=Read<int>(c3+0x18);if(r!=-99){Write<int>(c3+0x18,-99);gMod=true;}
}
