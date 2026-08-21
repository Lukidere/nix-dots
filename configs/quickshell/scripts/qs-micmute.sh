#!/bin/sh
# Toggle or read mute on the *physical* mic EasyEffects captures from, so muting
# actually silences the hardware (the default source is the EE virtual node,
# which apps using the raw mic bypass). Falls back to the default source when
# EasyEffects isn't configured.
#   qs-micmute.sh toggle   -> flip mute
#   qs-micmute.sh status   -> `wpctl get-volume` on the target (for [MUTED])
DB="$HOME/.config/easyeffects/db/easyeffectsrc"
dev=""
[ -f "$DB" ] && dev=$(sed -n 's/^inputDevice=//p' "$DB" | head -1)
id=""
[ -n "$dev" ] && id=$(pw-dump | jq -r --arg n "$dev" \
    '.[] | select(.info.props."node.name" == $n) | .id' 2>/dev/null | head -1)
target="${id:-@DEFAULT_AUDIO_SOURCE@}"
case "${1:-status}" in
    toggle) exec wpctl set-mute "$target" toggle ;;
    *)      exec wpctl get-volume "$target" ;;
esac
