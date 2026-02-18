# Sync local folder with iCloud via Rclone (Linux only).
#
# Usage:
#   sync-icloud [--force] [--resync]
export def sync-icloud [...args] {
   if (sys host | get name) != "Linux" {
      print "(ansi red)This function only works on Linux systems.(ansi reset)"
      return
   }
   if (^rclone config dump | from json | get "icloud") == null {
      print "(ansi red)Error: 'icloud' remote not found in rclone config.(ansi reset)"
      return
   }

   let src = "icloud:important"
   let dst = $"($env.HOME)/icloud-drive"

   if (which notify-send | is-not-empty) {
      ^notify-send "iCloud Sync" "Starting bisync for 'important' folder..."
   }

   print $"(ansi cyan)Starting Bisync: ($src) <-> ($dst)(ansi reset)"
   let result = (
      ^rclone bisync $src $dst
      --compare size,modtime,checksum
      --create-empty-src-dirs
      --conflict-resolve newer
      --metadata
      --progress
      --verbose
      ...$args
      | complete
   )

   if $result.exit_code == 0 {
      if (which notify-send | is-not-empty) {
         ^notify-send "iCloud Sync" "Bisync completed successfully."
      }
      print $"(ansi green)Sync completed successfully.(ansi reset)"
   } else {
      if (which notify-send | is-not-empty) {
         ^notify-send "iCloud Sync Error" "Bisync failed. Check terminal output."
      }
      print $"(ansi red)Sync failed with exit code ($result.exit_code):(ansi reset)"
      print $result.stderr
   }
}
