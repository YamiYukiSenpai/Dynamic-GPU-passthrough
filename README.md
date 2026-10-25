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
    * Finds processes that are using the NVIDIA GPU, including ones inside Docker containers.
        * If any of them are in the `NEVER_KILL` list, the VM won't start, so it can't steal your GPU (which would kill your session).
        * GPU monitors in `AUTO_KILL` (e.g. `nvtop`) are closed without asking.
        * For anything else, a notification asks you what to do, with a 30 second countdown (`PROMPT_SECS`):
            * **Close them:** Docker containers and system services are stopped cleanly (and restarted after the VM shuts down); other processes are killed.
            * **Cancel** (or no answer): nothing is touched, and the VM doesn't start. virt-manager shows the reason at the end of its error message, e.g. "It was decided to let the NVIDIA GPU stay on the host (in use by: container comfyui-cu130)".
    * Once nothing is holding the NVIDIA GPU, it'll unload the NVIDIA modules.  If one won't unload, the error says which one and how many users it still has.
    * After the VM shuts down (or if it fails to start), it reloads the driver, rebinds the card, and restarts whatever it stopped.
        * Before restarting containers, it regenerates Docker's CDI spec (via the Docker snap's `nvidia-container-toolkit` service, or `nvidia-ctk`), since the card's `/dev/dri/cardN` number can change when the driver reloads.
    * Logs what it's doing to the journal: `journalctl -t gpu-handoff`.
    > **Important:**
    > * Add the process name of your desktop environment, or anything else you deem very important, to `NEVER_KILL`.
    > * Edit `GPU_BUS`, `GPU_SLOT` & `GPU_ADDR`.  Those values are from my own setup.
* `/etc/xdg/plasma-workspace/env/10-no-nvidia-display.sh` searches for any non-NVIDIA GPUs. If it finds one, it'll set the [`KWIN_DRM_DEVICES`][kwin] environment variable to those GPUs.  It also sets the environment variables [`VK_DRIVER_FILES`][vk], [`__EGL_VENDOR_LIBRARY_FILENAMES`][egl] and `__GLX_VENDOR_LIBRARY_NAME` so that desktop apps don't use the NVIDIA GPU either.
    * Zen Browser was snagging my NVIDIA GPU for video decoding because it was the first render node, so this points the VA-API/VDPAU drivers and `MOZ_DRM_DEVICE` at a non-NVIDIA GPU (it shows up as "RDD Process" in the hook's prompt).
* `/var/lib/flatpak/overrides/global` does the same for Flatpak apps, since they can't see the host paths above. It points them at the sandbox's own Mesa files.
* `/usr/local/bin/nvidia-run` is a way to run an app on the NVIDIA card when you want to. It only affects that launch; everything else stays on the default GPU.
    ```sh
    nvidia-run <command>
    nvidia-run flatpak run <app id>
    ```
    CUDA apps don't need it; these variables only affect graphics and video decoding.

[kwin]: https://invent.kde.org/plasma/kwin/-/wikis/Environment-Variables#kwin_drm_devices
[vk]: https://github.com/KhronosGroup/Vulkan-Loader/blob/main/docs/LoaderInterfaceArchitecture.md#active-environment-variables
[egl]: https://github.com/NVIDIA/libglvnd/blob/master/src/EGL/icd_enumeration.md

## Install
The directory structure in `rootfs/` mirrors `/`.
1. Install `libxml2` (Arch) / `libxml2-utils` (Ubuntu), and `libnotify` (Arch) / `libnotify-bin` (Ubuntu) from your package manager (`apt`, `pacman`, etc.).
2. Copy the files to the matching paths under `/`:
    > **Warning:** If you already have your own `nvidia.conf` in `/etc/modprobe.d` or a system-wide Flatpak override in `/var/lib/flatpak/overrides/global`, the command below will overwrite it. Back it up first, then copy your old settings from the backup into the new file.
    ```sh
    sudo cp -r rootfs/* /
    sudo chmod +x /etc/xdg/plasma-workspace/env/10-no-nvidia-display.sh
    sudo chmod +x /etc/libvirt/hooks/qemu.d/gpu-handoff
    sudo chmod +x /usr/local/bin/nvidia-run
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
5. If you only updated the Plasma script or the Flatpak override, log out and log back in.

## TODO
* LXD/LXC support: processes in LXD containers using the NVIDIA GPU are detected, but "Close them" kills them instead of stopping the container, and the container isn't restarted afterwards.  The hook should recognize the `lxc.payload.<name>` cgroup, stop the container with `lxc stop <name>`, and run `lxc start <name>` after the VM shuts down.

## License
MIT, see [LICENSE](LICENSE)