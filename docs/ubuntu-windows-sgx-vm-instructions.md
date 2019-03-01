## Ubuntu/Debian KVM SGX Kernel & Windows VM Guide

This guide will give you the process to get a Windows 10 KVM VM working with Intel SGX to use the fingerprint reader on your XPS 9570/9370.

This makes it possible to capture the USB traffic with [tshark and `usbmon`](https://wiki.wireshark.org/CaptureSetup/USB).

### 1: Build and install the Intel SGX KVM kernel

It's probably wise to start on a similar kernel version to that which you're building in step 1.2. The kvm-sgx repo use tags for the linux kernel versions, in this guide it's `v4.19.0`. Use `ukuu` or the `mainline` kernel downloads page to get the `v4.19` kernel before hand.

#### 1.1 Install build dependencies

These packages are needed to build the kernel, there may be others.
The libcurses package is needed only in case the graphical menuconfig is used.

```bash
sudo apt install git build-essential kernel-package fakeroot libncurses5-dev libssl-dev ccache libncurses-dev bison flex libelf-dev
```

#### 1.2 Build the kvm-sgx kernel

Run the provided [`build-kernel-kvm-sgx.sh`](build-kernel-kvm-sgx.sh) script to clone the KVM repo and build the kernel automatically.

The script will set the necessary kernel configuration for SGX.

#### 1.3 Install the kernel

If all goes well, you'll have the kernel inside the `build_dir` (e.g. `$HOME/build-linux-sgx`). Time to install the kernel, make sure that only the kernel `deb` files you built are in this folder to prevent installing other version first:

```bash
cd $HOME/build-linux-sgx
ls -la *.deb
sudo dpkg -i linux-*.deb
reboot
```

**Note:** If the kernel is an older kernel than the version you're currently running, you'll need to make sure your grub config is set to show the boot menu `/etc/default/grub` and on reboot head into Advanced boot options to select the kernel you built. The kernel will have the suffix `-kvm-sgx` next to the version number.

### 2: Install KVM

If you don't have KVM installed already, install it using the following steps.

#### 2.1 Make sure kvm device exists before installing

You can use `kvm-ok` from the `cpu-checker` package:

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
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
```

#### 2.3 Optionally install the virt-manager and stuff

```bash
sudo apt install virt-manager
```

Probably wise to reboot at this stage.

### 3. Build qemu-sgx


#### 3.1 Install build dependencies
```bash
 sudo apt build-dep qemu-system-x86
```

#### 3.2 Build qemu

Run the provided [`build-qemu-sgx.sh`](build-qemu-sgx.sh) script to clone the qemu-kvm repo and build it automatically.


### 4. Install Windows with qemu-kvm

Follow the instructions here to setup the Windows vm: [Windows 10 Virtualization with KVM](https://www.funtoo.org/Windows_10_Virtualization_with_KVM)

Or just install Windows 10 with virm-manager using the system qemu, the same image could be run later with qemu-sgx.

#### 4.1 Load the kvm_intel module

You will need to do this on any subsequent reboots I believe:
```bash
sudo modprobe kvm_intel
```

#### 4.2 Modifications to qemu command line

You can use the same command used by virt-manager (look at the output of `ps aux | grep [q]emu`) and adjust it to use qemu-sgx, and the fingerpirnt reader:

- Use the path to the built qemu-sgx (e.g. `$HOME/build-linux-sgx/qemu-sgx/build/install/bin/qemu-system-x86_64`)
- use `-cpu host`
- Add `epc=128m` to the `-machine` option to enable the SGX memory storage
- Pass through the fingerprint USB device

**Note:** If virt-manager used a `pc-q35-3.1` machine, change that to `pc-q35-3.0` as qemu-sgx may not be up to date with upstream.

To get the device information run `lsusb` and note the bus and device number:
```bash
lsusb |grep '27c6:5395'
Bus 001 Device 005: ID 27c6:5395

```

In the `-usb -device` section, make sure the `hostbus` and `hostaddr` match bus and device respectively.
Also ensure your paths to your `isos` are correct as per the KVM Windows guide.

An example can be the following `vm.sh` script:


```bash
#!/bin/sh

WINIMG="$HOME/vm/Win10_1607_EnglishInternational_x64.iso"
VIRTIMG="$HOME/vm/virtio-win-0.1.160.iso"

# path to the build folder for qemu-sgx
QEMUSGX="$HOME/qemu-sgx/build/install"

$QEMUSGX/bin/qemu-system-x86_64 \
  -L "$QEMUSGX/../pc-bios" \
  --enable-kvm \
  -cpu host \
  -machine epc=128m \
  -m 2048 \
  -smp cores=2,threads=4 \
  -rtc base=localtime,clock=host \
  -drive driver=raw,file=$HOME/vm/win10.img,if=virtio \
  -drive file=${VIRTIMG},index=3,media=cdrom \
  -net nic,model=virtio -net user -cdrom ${WINIMG} \
  -usb -device usb-tablet \
  -usb -device usb-host,hostbus=1,hostaddr=5
```

#### 4.3 Start the Windows VM

```bash
cd ~/vm
sudo ./vm.sh
```

#### 4.4 Install the drivers

1. Install network `virtio` drivers in device manager
2. Download and install the Goodix Fingerprint drivers from [Dell Support](https://www.dell.com/support/home/au/en/aubsdt1/product-support/product/xps-15-9570-laptop/drivers)
3. Install the Intel SGX Driver for [Windows](https://downloadcenter.intel.com/download/28154/Intel-Software-Guard-Extensions-Intel-SGX-Driver-for-Windows-)

Reboot the VM.

#### 4.5 Enroll your fingerprint in your account

Go to `Settings > Accounts` and find the wizard to enroll your fingerprint. Lock Windows and test it works!
