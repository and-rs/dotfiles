# Example
# let files = (spinner "Listing files" { sleep 2sec; ls })
# Show a spinner while a closure runs, then return closure output.
def spinner [msg: string action: closure] {
  if not $nu.is-interactive {
    let value = (do $action)
    return $value
  }

  let frames = ["⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏"]
  let job_id = (
    job spawn {
      let result = (
        try {
          {ok: true value: (do $action)}
        } catch {|err|
          {ok: false msg: $err.msg}
        }
      )
      $result | job send 0
    }
  )

  mut i = 0
  loop {
    let result = (try { job recv --timeout 80ms } catch { null })
    if $result != null {
      print -n $"\r(ansi reset)"
      if not $result.ok {
        error make {msg: $result.msg}
      }
      return $result.value
    }

    let frame = ($frames | get ($i mod ($frames | length)))
    print -n $"\r(ansi reset)($frame) ($msg)..."
    $i = $i + 1
  }
}
