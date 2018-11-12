
## Ubuntu KVM SGX Kernel & Windows VM Guide

This guide will give you the process to get a Windows 10 KVM VM working with Intel SGX to use the fingerprint reader on your XPS 9570.

### 1: Build and install the Intel SGX KVM kernel

It's probably wise to start on a similar kernel version to that which you're building in step 1.2. The kvm-sgx repo use tags for the linux kernel versions, in this guide it's `v4.19.0`. Use `ukuu` or the `mainline` kernel downloads page to get the `v4.19` kernel before hand. 

#### 1.1 Install build dependancies

These packages are needed to build the kernel, there may be others. 
The libcurses package is needed for the graphical menuconfig.
```bash
sudo apt install git build-essential kernel-package fakeroot libncurses5-dev libssl-dev ccache libncurses-dev bison flex libelf-dev
```

#### 1.2 Build the kvm-sgx kernel

The following script will clone the KVM repo and build the kernel for you:
```bash
#!/bin/bash
version="sgx-v4.19.1-r1"
suffix="-kvm-sgx"
git_repo="https://github.com/intel/kvm-sgx.git"
build_dir="/tmp/build-sgx-kernel"
build_threads="12"

echo "Making build dir"
[ -d $build_dir ] || mkdir $build_dir

echo "Cloning kernel tag $version"
time git clone --depth 1 --branch $version $git_repo $build_dir

echo "Copying config for kernel build"
cp $(ls -t /boot/config-* | head -n1) $build_dir/.config

echo "Setting KVM SGX flag in kernel config"
sed -i "s/# CONFIG_INTEL_SGX_CORE is not set/CONFIG_INTEL_SGX_CORE=y/g" $build_dir/.config

cd $build_dir

echo "Disabling Debug Components to speed build"
scripts/config --disable DEBUG_INFO

echo "Make oldconfig"
yes "" | make oldconfig >/dev/null

read -n1 -r -p "Press any key to launch make menuconfig" key
make menuconfig

echo "Building Kernel"
time make -j$build_threads deb-pkg LOCALVERSION=$suffix >/dev/null 2> >(tee -a $build_dir/build-errors.log >&2)
```
During the kernel build you'll get the menuconfig screen appear, you will need to go and enable the SGX driver to be included in the build config. At the top menu, type `/` for search and enter `sgx`. It'll tell you the path in the `driver` menu to enable the `sgx` driver. Once you've located it, press `y` to select, save your config and exit to continue the build.

Copy the contents above into file, make it executable and run it as `sudo`:
```bash
cd /tmp
vim build.sh
[paste and save]
chmod +x build.sh
sudo ./build.sh
```

#### 1.3 Install the kernel

If all goes well, you'll have the kernel in the parent directory of the `build_dir`. Time to install the kernel, make sure that only the kernel `deb` files you built are in this folder to prevent installing other version first:
```bash
cd /tmp
ls -la *.deb
sudo dpkg -i linux-*.deb
reboot
```

**Note:** If the kernel is an older kernel than the version you're currently running, you'll need to make sure your grub config is set to show the boot menu `/etc/default/grub` and on reboot head into Adanced boot options to select the kernel you built. The kernel will have the suffix `-kvm-sgx` next the the version number.

### 2: Install KVM

If you don't have KVM installed already, install it using the following steps.

#### 2.1 Make sure kvm device exists before installing 
```bash
kvm-ok
```
Which should output something like
```bash
INFO: /dev/kvm exists
KVM acceleration can be used
```
#### 2.2 Install the kvm packages
```bash
sudo apt-get install qemu-kvm libvirt-bin ubuntu-vm-builder bridge-utils
```
#### 2.3 Optionally install the virtmanager and stuff
```bash
sudo libvirt-clients libvirt-daemon-system virt-manager
```

Probably wise to reboot at this stage.


### 3. Build qemu-sgx

#### 3.1 Load the kvm_intel module

You will need to do this on any subsequent reboots I believe:
```bash
sudo modprobe kvm_intel sgx=0
```

#### 3.2 Install build dependancies
```bash
sudo apt-get install git git-email libaio-dev libbluetooth-dev libbrlapi-dev libbz2-dev libcap-dev libcap-ng-dev libcurl4-gnutls-dev libfdt-dev libglib2.0-dev libgtk-3-dev libibverbs-dev libjpeg8-dev liblzo2-dev libncurses5-dev libnuma-dev libpixman-1-dev librbd-dev librdmacm-dev libsasl2-dev libsdl1.2-dev libseccomp-dev libsnappy-dev libssh2-1-dev libusb-dev libvde-dev libvdeplug-dev libvte-dev libxen-dev valgrind xfslibs-dev zlib1g-dev
```

**Note:** After you build qemu, you will need to keep the checked out repo folder as the build folder will make symlinks to files in the repo root. I built mine in `/usr/src` and then copied the build folder to `/opt/qemu-sgx` because of linux conventions. 

It's probably better practice to build the package in a non-root folder first and move the `build` folder to where you like later avoiding running `sudo` on builds is wise.

#### 3.3 Build qemu
```bash
build_threads="12"
cd /usr/src
sudo git clone https://github.com/intel/qemu-sgx.git
cd qemu-sgx/
sudo mkdir build
cd build
sudo ../configure --target-list=x86_64-softmmu --prefix=/usr --enable-debug --enable-libusb --enable-kvm --enable-seccomp
sudo make -j$build_threads
```

#### 3.4 Optional: Copy build folder to a different location

Remember, don't move the git repo clone folder or your symlinks will break!
```
cd ..
sudo cp -r build /opt/qemu-sgx
```

### 4. Install Windows with qemu-kvm

Follow the instructions here to setup the Windows vm: [Windows 10 Virtualization with KVM](https://www.funtoo.org/Windows_10_Virtualization_with_KVM)

#### 4.1 Modifications to `vm.sh`

- Included the path to the built qmeu-sgx
- Added the `-machine epc=2g` for SGX memory storage
- Pass through the fingerprint USB device

To get the device information run `lsusb` and note the bus and device number:
```bash
lsusb
Bus 002 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub
Bus 001 Device 005: ID 27c6:5395  
Bus 001 Device 003: ID 0cf3:e300 Atheros Communications, Inc. 
Bus 001 Device 006: ID 046d:c539 Logitech, Inc. 
Bus 001 Device 004: ID 05ac:0220 Apple, Inc. Aluminum Keyboard (ANSI)
Bus 001 Device 002: ID 05ac:1006 Apple, Inc. Hub in Aluminum Keyboard
Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub

```

In the `-usb -device` section, make sure the hostbus and hostaddr match bus and device respectively.
Also ensure your paths to your `isos` are correct as per the KVM Windows guide.
```bash
#!/bin/sh
WINIMG=/home/berg/vm/Win10_1607_EnglishInternational_x64.iso
VIRTIMG=/home/berg/vm/virtio-win-0.1.160.iso
# path to the build folder for qemu-sgx
QEMUSGX=/opt/qemu-sgx
/opt/qemu-sgx/x86_64-softmmu/qemu-system-x86_64 -L ${QEMUSGX} --enable-kvm -drive driver=raw,file=/home/berg/vm/win10.img,if=virtio -m 6144 \
-net nic,model=virtio -net user -cdrom ${WINIMG} \
-drive file=${VIRTIMG},index=3,media=cdrom \
-usb -device usb-host,hostbus=1,hostaddr=5  \
-machine epc=2g \
-rtc base=localtime,clock=host -smp cores=4,threads=8 \
-usb -device usb-tablet -cpu host
```

#### 4.2 Start the Windows VM

```bash
cd ~/vm
sudo ./vm.sh
```

#### 4.3 Install the drivers

1. Install network `virtio` drivers in device manager
2. Download and install the Goodix Fingerprint drivers from [Dell Support](https://www.dell.com/support/home/au/en/aubsdt1/product-support/product/xps-15-9570-laptop/drivers)
3. Install the Intel SGX Driver for [Windows](https://downloadcenter.intel.com/download/28154/Intel-Software-Guard-Extensions-Intel-SGX-Driver-for-Windows-)

Reboot VM

#### 4.4 Enroll your fingerprint in your account

Go to Settings > Accounts and find the wizard to enroll your fingerprint. Lock Windows and test it works!
