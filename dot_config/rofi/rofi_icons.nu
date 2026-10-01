# Vertical centering is computed, not eyeballed.
#
# Pango aligns every run on a shared baseline and `rise` shifts a run up
# (positive) in points. Two runs look centered when their glyph *ink* centers
# land at the same height above the baseline:
#
#     ICON_RISE + icon_ink_center = LABEL_RISE + label_ink_center
#
# Ink centers below are measured from the actual font files (glyf bounding
# boxes), expressed as a fraction of the em, then scaled by the point size:
#
#   Phosphor-Bold glyf ink y = [-64, 960] over 1024 upm
#     -> center = (-64 + 960) / 2 / 1024 = 0.4375 em
#   SF Pro cap "H" ink y = [0, 1443], x-height = 1040 over 2048 upm
#     -> cap center = 1443/2/2048 = 0.3523 em ; x center = 1040/2/2048 = 0.2539 em
#     -> mixed-case optical center (cap+x)/2 = 0.3031 em
#
# We anchor the label at its natural position (LABEL_RISE = 0) and shift the
# icon down to meet the label's mixed-case center.
const ICON_FONT = "Phosphor-Bold"
const ICON_SIZE = 13
const ICON_INK_CENTER = 0.4375 # (-64 + 960) / 2 / 1024
const LABEL_SIZE = 11
const LABEL_INK_CENTER = 0.2500 # mixed-case optical center of SF Pro

const LABEL_FONT = $"SF Pro ($LABEL_SIZE)"
const LABEL_RISE = "0pt"
const ICON_RISE = $"(($LABEL_INK_CENTER * $LABEL_SIZE) - ($ICON_INK_CENTER * $ICON_SIZE))pt"

const ICONS = {
  screenshot: "E10E"
  recording: "E3EE"
  selection: "E1D6"
  window: "E5DA"
  screen: "E560"
  back: "E138"
  no_audio: "E456"
  desktop_audio: "E560"
  microphone: "E326"
  mixed_audio: "E450"
  lockscreen: "E308"
  logout: "E5DE"
  suspend: "E53E"
  hibernate: "E0CC"
  reboot: "E036"
  shutdown: "E3DA"
  cancel: "E138"
}

export def rofi-icon [name: string] {
  let glyph = ($ICONS | get -o $name)
  if $glyph == null {
    error make {msg: $"unknown Rofi icon: ($name)"}
  }
  $glyph
}

# Escape Pango markup metacharacters so arbitrary label text stays literal.
def escape-markup [text: string] {
  $text
  | str replace --all "&" "&amp;"
  | str replace --all "<" "&lt;"
  | str replace --all ">" "&gt;"
}

# Build the icon span from a named glyph.
def icon-span [name: string] {
  {
    font: $"($ICON_FONT) ($ICON_SIZE)"
    rise: $ICON_RISE
    glyph: (rofi-icon $name)
  }
  | format pattern '<span font="{font}" rise="{rise}">&#x{glyph};</span>'
}

# Build the label span from arbitrary text.
def label-span [label: string] {
  {
    font: $LABEL_FONT
    rise: $LABEL_RISE
    text: (escape-markup $label)
  }
  | format pattern '<span font="{font}" rise="{rise}">{text}</span>'
}

export def rofi-row [name: string label: string --no-icon --no-text] {
  let parts = []
  let parts = if $no_icon { $parts } else { $parts | append (icon-span $name) }
  let parts = if $no_text { $parts } else { $parts | append (label-span $label) }
  $parts | str join "  "
}
