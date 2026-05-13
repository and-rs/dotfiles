# Pi agent setup

## Extensions

- `web-docs`: `/exa` auth command, `exa_search`, `web_fetch`.
- `hashline-edit`: strict `hashline_read`, `hashline_edit`, and `file_create` tools.
- `focus-border`: dim input border on terminal focus loss.
- `lib`: shared extension helpers. Not loaded as an extension.

## Exa auth

- `/exa login`: save regular Exa search API key as `auth.exa`.
- `/exa status`: show regular Exa key source.
- `/exa logout`: remove regular Exa key.
- `/exa service-login`: save Exa service/admin key as `auth.exa_service`.
- `/exa service-status`: show service key source.
- `/exa usage`: show 30-day Exa spend using service/admin key.
- `/exa service-logout`: remove service key.

Env fallbacks:

- `EXA_API_KEY`
- `EXA_SERVICE_KEY`

Stored key values may also be an env var name or `!command` that prints a key.

## Bootstrap

Run after clone/update:

```nu
ai bootstrap web-docs
ai bootstrap hashline-edit
ai bootstrap focus-border
```

## Tmux focus

Required for pane-switch dimming:

```nu
tmux set-option -g focus-events on
```

Restart tmux if existing panes still do not emit focus events.


## Keybindings

- `alt+p`: toggle session path filter.
- `alt+o`: toggle model provider.

## Local secrets

`auth.json` is local-only and ignored. Do not commit plaintext provider or Exa keys.
