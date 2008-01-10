HERE=$(PWD)
LINUX=$(HERE)/../linux-2.6

all: vfs.posix vfs.apr vfs.nt net.linux 
#vfs.ntk

include/asm:
	-mkdir `dirname $@`
	ln -s $(LINUX)/include/asm-lkl include/asm

include/asm-i386:
	-mkdir `dirname $@`
	ln -s $(LINUX)/include/asm-i386 include/asm-i386

include/asm-generic:
	-mkdir `dirname $@`
	ln -s $(LINUX)/include/asm-generic include/asm-generic

include/linux:
	-mkdir `dirname $@`
	ln -s $(LINUX)/include/linux include/linux

INC=include/asm include/asm-generic include/asm-i386 include/linux 

CFLAGS=-Wall -g

ENVS=posix linux apr nt ntk

nt_CROSS=i586-mingw32msvc-
nt_EXTRA_CFLAGS=-gstabs+

ntk_CROSS=i586-mingw32msvc-
ntk_LD_FLAGS=-Wl,--subsystem,native -Wl,--entry,_DriverEntry@8 -nostartfiles \
		-lntoskrnl -lhal -nostdlib -shared
ntk_EXTRA_CFLAGS=-gstabs+ -D_WIN32_WINNT=0x0500

posix_LD_FLAGS=-lpthread

linux_LD_FLAGS=-lpthread
#linux_CROSS=/opt/cegl-2.0/powerpc-750-linux-gnu/gcc-3.3.4-glibc-2.3.3/bin/powerpc-750-linux-gnu-

apr_EXTRA_CFLAGS=-I/usr/include/apr-1.0/ -D_LARGEFILE64_SOURCE
apr_LD_FLAGS=-L/usr/lib/debug/usr/lib -lapr-1

%/.config: %.config 
	mkdir -p $* && \
	cp $< $@

%/vmlinux: %/.config 
	cd $(LINUX) && \
	$(MAKE) O=$(HERE)/$* ARCH=lkl \
	CROSS_COMPILE=$($*_CROSS) \
	EXTRA_CFLAGS="$($*_EXTRA_CFLAGS) $(CFLAGS)" \
	vmlinux

%/env.a: %/.config 
	cd $(LINUX) && \
	$(MAKE) O=$(HERE)/$* ARCH=lkl \
	CROSS_COMPILE=$($*_CROSS) \
	EXTRA_CFLAGS="$($*_EXTRA_CFLAGS) $(CFLAGS)" \
	env.a

define env_template

.PRECIOUS: $(1)/.config $(1)/vmlinux $(1)/env.a

%.$(1): %.c $(1)/vmlinux $(1)/env.a $(INC)
	$($(1)_CROSS)gcc $$(CFLAGS) $($(1)_EXTRA_CFLAGS) -Iinclude -I$(1)/include $$*.c $(1)/vmlinux $(1)/env.a $($(1)_LD_FLAGS) -o $$@
endef

$(foreach env,$(ENVS),$(eval $(call env_template,$(env))))

clean:
	-rm -rf apr linux posix nt ntk 
	-rm -f include/asm include/asm-i386 include/asm-generic include/linux	
	-rmdir include
	-rm -f $(patsubst %,*.%,$(ENVS))


