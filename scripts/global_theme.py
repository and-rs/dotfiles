import json
from pathlib import Path

colors = Path("scripts/colors.json")
neovim = Path("/home/and-rs/Vault/personal/nvim/lua/config/settings.lua")

with open(colors) as f:
    all_colors = json.load(f)

current_mode = neovim.read_text()
target_mode = "light" if "dark" in current_mode else "dark"
colors = all_colors[target_mode]

templates = {
    neovim: f'vim.opt.background = "{target_mode}"',
}

for path, template in templates.items():
    Path(path).write_text(template.format(**colors))
