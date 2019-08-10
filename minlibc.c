extern int main();

// Minimal implementations of crt1.o libc functions.
// With these defined, we don't need to link libc. Probably.
void __libc_csu_init() {}
void __libc_csu_fini() {}
void __libc_start_main() { main(); }
