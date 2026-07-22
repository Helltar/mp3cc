/* align PT_TLS for the ARM Bionic thread control block */
__thread unsigned char mp3cc_android_tls_alignment
    __attribute__((aligned(64), used));
