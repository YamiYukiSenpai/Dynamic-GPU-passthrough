# Dynamic GPU passthrough
Just a way to make my secondary RTX 4060 usable outside of being used by virtual machines.

> [!NOTE]
> I only tested this on my own setup with the following environment:
>
> * Garuda Linux
> * KDE Plasma
> * ASRock Radeon RX 6900 XT (primary GPU)
> * Gigabyte RTX 4060 low profile (secondary GPU)
> 
> I would suggest forking this yourself and tweaking it for your own particular setup, if needed (especially the desktop environment).

## How it works

The 3 components here do the following:

* `/etc/modprobe.d/nvidia.conf` modprobe file disables NVIDIA's framebuffer console so that the console won't keep `nvidia_drm` in use, which would make the hook's `modprobe -r` fail. Bonus benefit: no blinking text cursor.
* `/etc/libvirt/hooks/qemu.d/gpu-handoff`
    * Stops anything that's listed in `HOST_SERVICES` and `HOST_CONTAINERS`, along with `nvidia-persistenced`.  
    * Finds processes that are using the NVIDIA GPU, and kills them, unless any of them are in the `NEVER_KILL` list, which prevents the VM from starting and stealing your GPU (which would kill your session).
        * **WIP** Ideally, it should be asking via notification popup if I want to kill any processes that aren't in `AUTO_KILL`, but it doesn't seem to work yet (tested when I commented out the `NEVER_KILL` variable).
    * Once nothing is holding the NVIDIA GPU, it'll unload the NVIDIA modules.
    * After the VM shuts down, it reloads the driver and rebinds the card.  Ideally, it'll restart whatever it stopped, but I haven't tested that yet.
    > [!IMPORTANT]
    > * Add the process name of your desktop environment, or anything else you deem very important, to `NEVER_KILL`.
    > * Edit `GPU_BUS`, `GPU_SLOT` & `GPU_ADDR`.  Those values are from my own setup.
* `/etc/xdg/plasma-workspace/env/10-no-nvidia-display.sh` searches for any non-NVIDIA GPUs. If it finds one, it'll set the [`KWIN_DRM_DEVICES`][kwin] environment variable to those GPUs.  It also sets the environment variables [`VK_DRIVER_FILES`][vk] and [`__EGL_VENDOR_LIBRARY_FILENAMES`][egl] so that desktop apps don't use the NVIDIA GPU either.

[kwin]: https://invent.kde.org/plasma/kwin/-/wikis/Environment-Variables#kwin_drm_devices
[vk]: https://github.com/KhronosGroup/Vulkan-Loader/blob/main/docs/LoaderInterfaceArchitecture.md#active-environment-variables
[egl]: https://github.com/NVIDIA/libglvnd/blob/master/src/EGL/icd_enumeration.md

## Install
The directory structure in `rootfs/` mirrors `/`.
1. Install `libxml2` (Arch) / `libxml2-utils` (Ubuntu), `libnotify` (Arch) / `libnotify-bin` (Ubuntu) and `psmisc` from your package manager (`apt`, `pacman`, etc.).
2. Copy the files to the matching paths under `/`:
    > [!WARNING]
    > If you already have your own `nvidia.conf` in `/etc/modprobe.d`, the command below will overwrite it. Back it up first, then copy your old settings from the backup into the new file.
    ```sh
    sudo cp -r rootfs/* /
    sudo chmod +x /etc/xdg/plasma-workspace/env/10-no-nvidia-display.sh
    sudo chmod +x /etc/libvirt/hooks/qemu.d/gpu-handoff
    ```
3. Rebuild the initramfs, then reboot:
    * Garuda Linux
        ```sh
        sudo dracut-rebuild
        ```
    * Ubuntu >=25.10
        ```sh
        sudo dracut --regenerate-all --force
        ```
    * Ubuntu <=25.04
        ```sh
        sudo update-initramfs -u -k all
        ```
4. If you only updated the QEMU hook script, restart `libvirtd`:
    ```sh
    sudo systemctl restart libvirtd
    ```
5. If you only updated the Plasma script, log out and log back in.

## License
MIT, see [LICENSE](LICENSE)