# TESTWAIT
Simple program to measure the number of wait states on an Intel 8088 or NEC V20 system

## Introduction
TESTWAIT measures the number of the wait states that a motherboard or an extension card insert when accessing memory or I/O ports
Currently it performs five measurements:
1. Main memory access speed: This is used as a calibration value for other measurements, assuming that the main memory is accessed without any wait states. The CPU clock cycle period is printed as the result of this calculation. It can be somewhat used to check that the main memory is indeed accessed without any wait states
2. Number of video memory wait states: Many video cards will generate wait states when accessing video memory. This measurement gives an optimisic (rounded down) estimate of the number of wait states inserted
3. Number of BIOS ROM wait states: ROMs are generally slower than RAM, so many motherboards add wait states when accessing ROMs, or in fact any memory above the first 640 KiB
4. Number of on-board I/O wait states. Port 61h (normally PPI, or so-called port B) is used for this measurement
5. Number of extension bus I/O wait states. COM1 MSR register is used for this measurement

TESTWAIT currently only supports Intel 8088 and NEC V20 CPUs. 8088 CPUs from other manufacturers are also expected to work. 8086 and NEC V30 might work as well, but have not been tested. It might be possible to add support for other relatively simple x86 CPUs, probably anything that is not using caches.
