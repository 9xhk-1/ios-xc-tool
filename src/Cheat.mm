#include "Cheat.h"
#include <mach/mach.h>
#include <mach-o/dyld_images.h>
#include <unistd.h>
static mach_port_t gTask=0;
static bool gMod=false,gF=false; static uint64_t gBase=0,gActor=0;
template<typename T> static T Read(uint64_t a){T v{};vm_size_t s=sizeof(T);vm_read_overwrite(gTask,a,sizeof(T),(vm_address_t)&v,&s);return v;}
template<typename T> static void Write(uint64_t a,T v){vm_write(gTask,a,(vm_address_t)&v,sizeof(T));}
bool gAutoShoot=false; float gAimSpeed=5,gFovRadius=120;
void CheatTick(){
    if(!gAutoShoot){if(gMod&&gActor){uint64_t c1=Read<uint64_t>(gActor+0x708);
        if(c1>0x100000000){uint64_t c2=Read<uint64_t>(c1+0x20);if(c2>0x100000000){uint64_t c3=Read<uint64_t>(c2+0x40);
        if(c3>0x100000000)Write<int>(c3+0x18,1055286886);}}gMod=false;}return;}
    if(!gTask){task_for_pid(mach_task_self(),getpid(),&gTask);if(!gTask)return;}
    if(!gF){gF=true;task_dyld_info_data_t d;mach_msg_type_number_t n=TASK_DYLD_INFO_COUNT;
        if(task_info(mach_task_self_,TASK_DYLD_INFO,(task_info_t)&d,&n)==0){uint64_t p=d.all_image_info_addr;
        if(p>0x100000000){uint32_t c=Read<uint32_t>(p+8);uint64_t a=Read<uint64_t>(p+16);
        if(a>0x100000000)for(uint32_t i=0;i<c&&i<256;i++){uint64_t e=a+i*24;uint64_t pp=Read<uint64_t>(e);
        if(pp>0x100000000){char b[256]={};vm_size_t z=255;vm_read_overwrite(gTask,pp,255,(vm_address_t)b,&z);
        if(strstr(b,"Sausage")||strstr(b,"Unity")||strstr(b,"il2cpp")){gBase=Read<uint64_t>(e+16);break;}}}}}}
    if(!gBase)return;
    if(!gActor){uint64_t gw=0;
        for(uint64_t o=0;o<0x400000;o+=8){uint64_t v=Read<uint64_t>(gBase+o);if(v>0x100000000){uint64_t t=Read<uint64_t>(v+0x30);if(t>0x100000000){gw=v;break;}}}
        if(gw){uint64_t l=Read<uint64_t>(gw+0x30);if(l>0x100000000){uint64_t gs=Read<uint64_t>(l+0x498);if(gs>0x100000000){uint64_t pa=Read<uint64_t>(gs+0x2D0);if(pa>0x100000000){uint64_t p0=Read<uint64_t>(pa);if(p0>0x100000000){gActor=Read<uint64_t>(p0+0x20);}}}}}}
    if(!gActor||gActor<0x100000000){gActor=0;return;}
    uint64_t c1=Read<uint64_t>(gActor+0x708);if(!(c1>0x100000000))return;
    uint64_t c2=Read<uint64_t>(c1+0x20);if(!(c2>0x100000000))return;
    uint64_t c3=Read<uint64_t>(c2+0x40);if(!(c3>0x100000000))return;
    int r=Read<int>(c3+0x18);if(r!=-99){Write<int>(c3+0x18,-99);gMod=true;}
}
