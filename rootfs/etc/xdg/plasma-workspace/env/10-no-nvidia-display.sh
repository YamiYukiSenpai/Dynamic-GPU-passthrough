# Sourced by Plasma before KWin starts.
# Desktop output + desktop apps: non-NVIDIA GPUs only.
# NVIDIA GPUs stay free for CUDA / VM passthrough.

kwin_cards=""
for card in /sys/class/drm/card[0-9]*; do
    case "${card##*/}" in *-*) continue ;; esac          # skip connectors (card1-DP-1)
    [ -r "$card/device/vendor" ] || continue
    [ "$(cat "$card/device/vendor")" = "0x10de" ] && continue   # NVIDIA
    kwin_cards="${kwin_cards:+$kwin_cards:}/dev/dri/${card##*/}"
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
fi
