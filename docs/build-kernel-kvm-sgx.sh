#!/bin/bash

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

version="sgx-v5.0.0-r1"
suffix="-kvm-sgx"
git_repo="https://github.com/intel/kvm-sgx.git"
build_threads="12"

if [ ! -d "$build_dir" ];
then
    echo "Making build dir"
    mkdir "$build_dir"
fi

cd "$build_dir"

if [ ! -d "kvm-sgx" ];
then
    echo "Cloning kernel tag $version"
    time git clone --depth 1 --branch "$version" "$git_repo"
fi

cd "$build_dir/kvm-sgx"

echo "Copying config for kernel build"
cp "$(ls -t /boot/config-* | head -n1)" ".config"

echo "Make oldconfig"
make olddefconfig >/dev/null
./scripts/config --module USB_COMMON
./scripts/config --set-str SYSTEM_TRUSTED_KEYS ""

echo "Setting KVM SGX flag in kernel config"
./scripts/config --enable INTEL_SGX_CORE

echo "Disabling Debug Components to speed build"
./scripts/config --disable DEBUG_INFO

echo "Building Kernel"
time make -j$build_threads bindeb-pkg LOCALVERSION="$suffix" 2> >(tee -a "$build_dir/build-errors.log" >&2)
