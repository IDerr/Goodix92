#!/bin/sh

set -e

# Use $HOME as a working directory for two reasons:
#
#   1. keep the built code around instead of putting it into /tmp and loose it
#      at the next reboot.;
#
#   2. avoid $PWD because it may contain white spaces and kbuild would not
#      work.
#
build_dir="$HOME/build-linux-sgx"

build_threads="12"

[ -d "$build_dir" ] || mkdir "$build_dir"

cd "$build_dir"

[ -d qemu-sgx ] || git clone https://github.com/intel/qemu-sgx.git

cd qemu-sgx/

git submodule update --init

[ -d build/ ] || mkdir build

cd build

# Try to match the configure options of the Debian package
../configure \
  --extra-cflags="-I/usr/include/capstone" \
  --target-list=x86_64-softmmu \
  --prefix="$PWD/install" \
  --disable-blobs \
  --disable-strip \
  --enable-debug \
  --disable-werror \
  --enable-capstone=system \
  --enable-linux-aio \
  --audio-drv-list=pa,alsa,oss \
  --enable-attr \
  --enable-bluez \
  --enable-brlapi \
  --enable-virtfs \
  --enable-cap-ng \
  --enable-curl \
  --enable-fdt \
  --enable-gnutls \
  --enable-gtk --enable-vte \
  --enable-libiscsi \
  --enable-curses \
  --enable-virglrenderer \
  --enable-opengl \
  --enable-libnfs \
  --enable-smartcard \
  --enable-rbd \
  --enable-glusterfs \
  --enable-vnc-sasl \
  --disable-sdl --with-sdlabi=2.0 \
  --enable-seccomp \
  --enable-rdma \
  --enable-libusb \
  --enable-usb-redir \
  --enable-libssh2 \
  --enable-vde \
  --enable-xfsctl \
  --enable-vnc \
  --enable-vnc-jpeg \
  --enable-vnc-png \
  --enable-kvm \
  --enable-vhost-net

make -j$build_threads
make install

echo
echo
echo "qemu can now be run from '$PWD/install/bin'"
