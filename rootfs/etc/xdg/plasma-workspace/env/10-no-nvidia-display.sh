# Sourced by Plasma before KWin starts.
# Desktop output + desktop apps: non-NVIDIA GPUs only.
# NVIDIA GPUs stay free for CUDA / VM passthrough.

kwin_cards=""
render_node=""
render_vendor=""
for card in /sys/class/drm/card[0-9]*; do
    case "${card##*/}" in *-*) continue ;; esac          # skip connectors (card1-DP-1)
    [ -r "$card/device/vendor" ] || continue
    vendor="$(cat "$card/device/vendor")"
    [ "$vendor" = "0x10de" ] && continue   # NVIDIA
    kwin_cards="${kwin_cards:+$kwin_cards:}/dev/dri/${card##*/}"

    # First non-NVIDIA render node, for video decoding
    if [ -z "$render_node" ]; then
        for r in "$card"/device/drm/renderD*; do
            [ -e "$r" ] && render_node="/dev/dri/${r##*/}" && render_vendor="$vendor" && break
        done
    fi
done

# Only restrict if a non-NVIDIA GPU exists - otherwise keep a usable desktop
if [ -n "$kwin_cards" ]; then
    export KWIN_DRM_DEVICES="$kwin_cards"

    vk=""
    for f in /usr/share/vulkan/icd.d/*.json; do
        case "${f##*/}" in nvidia*) continue ;; esac
        vk="${vk:+$vk:}$f"
    done
    [ -n "$vk" ] && export VK_DRIVER_FILES="$vk"

    egl=""
    for f in /usr/share/glvnd/egl_vendor.d/*.json; do
        case "${f##*/}" in *nvidia*) continue ;; esac
        egl="${egl:+$egl:}$f"
    done
    [ -n "$egl" ] && export __EGL_VENDOR_LIBRARY_FILENAMES="$egl"

    export __GLX_VENDOR_LIBRARY_NAME=mesa

    # Video decoding (VA-API/VDPAU). Firefox-based browsers otherwise use the
    # first render node, which can be the NVIDIA card (their "RDD Process").
    if [ -n "$render_node" ]; then
        export MOZ_DRM_DEVICE="$render_node"
        case "$render_vendor" in
            0x1002) export LIBVA_DRIVER_NAME=radeonsi VDPAU_DRIVER=radeonsi ;;   # AMD
            0x8086) export LIBVA_DRIVER_NAME=iHD ;;                              # Intel
        esac
    fi
fi
