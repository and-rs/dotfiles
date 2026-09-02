const TUNING = {
  # HSL lightness offsets for surface1 through surface5.
  surface_steps: [0.03 0.07 0.16 0.28 0.36]

  # Dark backgrounds need less accent tint than light backgrounds.
  dark_tint: {base: 0.03 slope: 0.2 maximum: 0.16}
  light_tint: {base: 0.08 slope: 0.5 maximum: 0.35}

  # Skip hue and saturation tinting for near-neutral backgrounds.
  achromatic_cutoff: 0.01

  # Rec. 709 RGB weights and the light/dark split point.
  luminance_weights: [0.2126 0.7152 0.0722]
  lightness_threshold: 0.5

  # HSL hue is normalized to one full turn.
  hue_turn: 1.0
  hue_wrap: 0.5
  hue_channel_offset: (1 / 3)
  hue_sixth: (1 / 6)
  hue_half: 0.5
  hue_two_thirds: (2 / 3)
}

const SURFACE_NAMES = [surface1 surface2 surface3 surface4 surface5]

def parse-color [color: string] {
  let hex = ($color | str replace --regex '^#' '')

  if $hex !~ '^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$' {
    error make {msg: $"invalid RGB color: ($color)"}
  }
  0..2 | each {|channel|
    $hex
    | str substring (($channel * 2)..(($channel * 2) + 1))
    | into int --radix 16
    | $in / 255
  }
}

def rgb-to-hsl [rgb: list<float>] {
  let max = ($rgb | math max)
  let min = ($rgb | math min)
  let lightness = ($max + $min) / 2

  if $max == $min {
    return {h: 0 s: 0 l: $lightness}
  }
  let delta = $max - $min
  let saturation = if $lightness > 0.5 {
    $delta / (2 - $max - $min)
  } else {
    $delta / ($max + $min)
  }
  let hue = if $max == $rgb.0 {
    (($rgb.1 - $rgb.2) / $delta + (if $rgb.1 < $rgb.2 { 1 } else { 0 })) / 6
  } else if $max == $rgb.1 {
    (($rgb.2 - $rgb.0) / $delta + 2) / 6
  } else {
    (($rgb.0 - $rgb.1) / $delta + 4) / 6
  }
  {h: $hue s: $saturation l: $lightness}
}

def hsl-channel [p: float q: float t: float] {
  let t = if $t < 0 {
    $t + $TUNING.hue_turn
  } else if $t > $TUNING.hue_turn {
    $t - $TUNING.hue_turn
  } else {
    $t
  }

  if $t < $TUNING.hue_sixth {
    $p + ($q - $p) * 6 * $t
  } else if $t < $TUNING.hue_half {
    $q
  } else if $t < $TUNING.hue_two_thirds {
    $p + ($q - $p) * 6 * ($TUNING.hue_two_thirds - $t)
  } else {
    $p
  }
}

def hsl-to-rgb [hsl: record] {
  let hue = ($hsl.h | into float)
  let saturation = ($hsl.s | into float)
  let lightness = ($hsl.l | into float)
  let q = if $lightness < 0.5 {
    $lightness * (1 + $saturation)
  } else {
    $lightness + $saturation - $lightness * $saturation
  }
  let p = 2 * $lightness - $q

  [
    (hsl-channel $p $q ($hue + $TUNING.hue_channel_offset))
    (hsl-channel $p $q $hue)
    (hsl-channel $p $q ($hue - $TUNING.hue_channel_offset))
  ]
}

def format-color [rgb: list<float>] {
  $rgb
  | each {|channel| $channel * 255 | math round }
  | each {|channel|
    $channel
    | into int
    | format number --no-prefix
    | get lowerhex
    | str replace --regex '^0x' ''
    | if ($in | str length) == 1 { $"0($in)" } else { $in }
  }
  | str join
  | $"#($in)"
}

def surface-colors [bg: string accent: string] {
  let bg_rgb = (parse-color $bg)
  let bg_hsl = (rgb-to-hsl $bg_rgb)
  let accent_rgb = (parse-color $accent)
  let accent_hsl = (rgb-to-hsl $accent_rgb)
  let light = (($bg_rgb.0 * $TUNING.luminance_weights.0) + ($bg_rgb.1 * $TUNING.luminance_weights.1) + ($bg_rgb.2 * $TUNING.luminance_weights.2)) > $TUNING.lightness_threshold

  $TUNING.surface_steps | enumerate | reduce -f {} {|surface result|
    let name = $SURFACE_NAMES | get $surface.index
    let amount = $surface.item
    let lightness = if $light {
      let value = $bg_hsl.l - $amount
      if $value < 0 { 0 } else { $value }
    } else {
      let value = $bg_hsl.l + $amount
      if $value > 1 { 1 } else { $value }
    }
    let tint_profile = if $light { $TUNING.light_tint } else { $TUNING.dark_tint }
    let tint_value = $tint_profile.base + $amount * $tint_profile.slope
    let tint = if $tint_value > $tint_profile.maximum { $tint_profile.maximum } else { $tint_value }
    let hue_distance = $accent_hsl.h - $bg_hsl.h
    let hue_distance = if $hue_distance > $TUNING.hue_wrap {
      $hue_distance - $TUNING.hue_turn
    } else if $hue_distance < (0 - $TUNING.hue_wrap) {
      $hue_distance + $TUNING.hue_turn
    } else {
      $hue_distance
    }
    let hsl = if $bg_hsl.s > $TUNING.achromatic_cutoff {
      let saturation_value = $bg_hsl.s + ($accent_hsl.s - $bg_hsl.s) * $tint
      {
        h: ($bg_hsl.h + $hue_distance * $tint)
        s: (if $saturation_value > 1 { 1 } else { $saturation_value })
        l: $lightness
      }
    } else {
      {h: $bg_hsl.h s: $bg_hsl.s l: $lightness}
    }

    $result | upsert $name (format-color (hsl-to-rgb $hsl))
  }
}

def color-vec4 [color: string] {
  let channels = (
    parse-color $color
    | each {|channel| $channel | into string --decimals 6 }
    | str join ', '
  )
  "vec4(" + $channels + ", 1.0)"
}

def main [mode: string color?: string accent?: string] {
  match $mode {
    'surfaces' => (surface-colors $color $accent | to json -r)
    'vec4' => (color-vec4 $color)
    _ => (error make {msg: $"unknown palette mode: ($mode)"})
  }
}
