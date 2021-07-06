#include <stdio.h>
#if defined(_MSC_VER)
#include <intrin.h>
#endif

static inline void native_cpuid(unsigned int *eax, unsigned int *ebx,
                                unsigned int *ecx, unsigned int *edx)
{
    /* ecx is often an input as well as an output. */

#if !defined(_MSC_VER)

    asm volatile("cpuid"
                 : "=a"(*eax),
                   "=b"(*ebx),
                   "=c"(*ecx),
                   "=d"(*edx)
                 : "0"(*eax), "2"(*ecx));

#else
    int registers[4] = {0, 0, 0, 0};

    __cpuidex(registers, *eax, *ecx);
    *eax = registers[0];
    *ebx = registers[1];
    *ecx = registers[2];
    *edx = registers[3];

#endif
}

int main(int argc, char **argv)
{
    /* This programm prints some CPUID information and tests the SGX support of the CPU */
    unsigned eax, ebx, ecx, edx;
    int is_sgx_available = 0;
    int is_sgx_enable = 0;
    eax = 1; /* processor info and feature bits */

    native_cpuid(&eax, &ebx, &ecx, &edx);
    printf("eax: %x ebx: %x ecx: %x edx: %x\n", eax, ebx, ecx, edx);

    printf("stepping %d\n", eax & 0xF);                 // Bit 3-0
    printf("model %d\n", (eax >> 4) & 0xF);             // Bit 7-4
    printf("family %d\n", (eax >> 8) & 0xF);            // Bit 11-8
    printf("processor type %d\n", (eax >> 12) & 0x3);   // Bit 13-12
    printf("extended model %d\n", (eax >> 16) & 0xF);   // Bit 19-16
    printf("extended family %d\n", (eax >> 20) & 0xFF); // Bit 27-20

    // if smx set - SGX global enable is supported
    printf("smx: %d\n", (ecx >> 6) & 1); // CPUID.1:ECX.[bit6]

    /* Extended feature bits (EAX=07H, ECX=0H)*/
    printf("\nExtended feature bits (EAX=07H, ECX=0H)\n");
    eax = 7;
    ecx = 0;
    native_cpuid(&eax, &ebx, &ecx, &edx);
    printf("eax: %x ebx: %x ecx: %x edx: %x\n", eax, ebx, ecx, edx);

    //CPUID.(EAX=07H, ECX=0H):EBX.SGX = 1,
    is_sgx_available = (ebx >> 2) & 0x1;
    printf("sgx available: %d\n", is_sgx_available);

    //CPUID.(EAX=07H, ECX=0H):ECX.SGX_LC = 1
    printf("sgx launch control: %d\n", (ecx >> 30) & 0x01);

    /* SGX has to be enabled in MSR.IA32_Feature_Control.SGX_Enable
	check with msr-tools: rdmsr -ax 0x3a
	SGX_Enable is Bit 18
	if SGX_Enable = 0 no leaf information will appear. 
     for more information check Intel Docs Architectures-software-developer-system-programming-manual - 35.1 Architectural MSRS
  */

    /* CPUID Leaf 12H, Sub-Leaf 0 Enumeration of Intel SGX Capabilities (EAX=12H,ECX=0) */
    printf("\nCPUID Leaf 12H, Sub-Leaf 0 of Intel SGX Capabilities (EAX=12H,ECX=0)\n");
    eax = 0x12;
    ecx = 0;
    native_cpuid(&eax, &ebx, &ecx, &edx);
    printf("eax: %x ebx: %x ecx: %x edx: %x\n", eax, ebx, ecx, edx);

    printf("sgx 1 supported: %d\n", eax & 0x1);
    printf("sgx 2 supported: %d\n", (eax >> 1) & 0x1);
    is_sgx_enable = (eax & 0x1) || ((eax >> 1) & 0x1);

    printf("MaxEnclaveSize_Not64: %x\n", edx & 0xFF);
    printf("MaxEnclaveSize_64: %x\n", (edx >> 8) & 0xFF);

    /* CPUID Leaf 12H, Sub-Leaf 1 Enumeration of Intel SGX Capabilities (EAX=12H,ECX=1) */
    printf("\nCPUID Leaf 12H, Sub-Leaf 1 of Intel SGX Capabilities (EAX=12H,ECX=1)\n");
    eax = 0x12;
    ecx = 1;
    native_cpuid(&eax, &ebx, &ecx, &edx);
    printf("eax: %x ebx: %x ecx: %x edx: %x\n", eax, ebx, ecx, edx);

    int i;
    for (i = 2; i < 10; i++)
    {
        /* CPUID Leaf 12H, Sub-Leaf i Enumeration of Intel SGX Capabilities (EAX=12H,ECX=i) */
        printf("\nCPUID Leaf 12H, Sub-Leaf %d of Intel SGX Capabilities (EAX=12H,ECX=%d)\n", i, i);
        eax = 0x12;
        ecx = i;
        native_cpuid(&eax, &ebx, &ecx, &edx);
        printf("eax: %x ebx: %x ecx: %x edx: %x\n", eax, ebx, ecx, edx);
    }

    if (is_sgx_available != 1)
    {
        printf("\033[31m\nCPU SGX functions are deactivated or SGX is not supported!\033[0m\n");
        return 1;
    }
    else if (is_sgx_enable != 1)
    {
        printf("\033[31m\nSGX is available for your CPU but not enabled in BIOS!\033[0m\n");
        return 2;
    }

    printf("\033[32m\nSGX is available for your CPU and enabled in BIOS!\033[0m\n");
    return 0;
}
