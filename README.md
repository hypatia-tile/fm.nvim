# fm.nvim

Talk to [`fm`](https://developer.apple.com/videos/play/wwdc2026/334/) (Apple Foundation Models CLI) from a hover-style floating window in Neovim.

## Requirements

- Neovim **0.9+**
- **macOS 27+** with Apple Intelligence enabled (Apple silicon)
- `fm` on your `PATH` (ships as `/usr/bin/fm`)
- Accept the CLI license once: `sudo fm license`

## Features

- Hover / floating chat window with streaming replies from `fm respond`
- Multi-turn conversations via `--save-transcript` / `--resume`
- Send the visual selection as context (`--text`)
- Stop / clear / configurable model (`system` or `pcc`)
- `:checkhealth fm`

## Install

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "hypatia-tile/fm.nvim",
  cmd = { "Fm", "FmAsk", "FmAskSelection", "FmClear", "FmStop", "FmClose" },
  keys = {
    -- lhs-only entries lazy-load the plugin, then use keymaps from setup()
    { "<leader>fm", mode = { "n", "v" }, desc = "Toggle fm chat" },
    { "<leader>fa", mode = "v", desc = "Ask fm about selection" },
  },
  opts = {}, -- optional; defaults work out of the box
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use({
  "hypatia-tile/fm.nvim",
  config = function()
    require("fm").setup()
  end,
})
```

## Usage

| Command | Action |
| --- | --- |
| `:Fm` | Toggle the hover chat window |
| `:Fm Explain this buffer` | Ask immediately |
| `:FmAsk {prompt}` | Same as asking with a prompt |
| `:'<,'>FmAskSelection` | Ask about the visual selection |
| `:FmClear` | Reset conversation + transcript |
| `:FmStop` | Cancel generation |
| `:FmClose` | Close the window |

Inside the hover window:

| Key | Action |
| --- | --- |
| `<CR>` | Send the prompt |
| `<C-Enter>` / `<S-CR>` | Insert a newline |
| `q` / `<Esc>` | Close |
| `<C-l>` | Clear conversation |
| `<C-c>` | Stop generation |

Default global maps (set in `setup`):

- `<leader>fm` — toggle chat
- `<leader>fa` — ask about visual selection

## Configuration

```lua
require("fm").setup({
  cmd = "fm",
  model = "system", -- "system" (on-device) or "pcc" (Private Cloud Compute)
  instructions = "You are a helpful coding assistant inside Neovim. Be concise and practical.",
  stream = true,
  greedy = false,
  transcript_dir = vim.fn.stdpath("cache") .. "/fm.nvim",
  timeout = 0,            -- kill fm after this many ms (0 = no limit)
  window = {
    width = 0.6,          -- fraction of columns, or absolute
    height = 0.5,         -- fraction of lines, or absolute
    border = "rounded",
    title = " fm ",
    relative = "editor",  -- use "cursor" for LSP-style hover placement
    input_height = 3,
  },
  keymaps = {
    toggle = "<leader>fm",
    ask_selection = "<leader>fa",
    send = "<CR>",
    close = "q",
    clear = "<C-l>",
    stop = "<C-c>",
  },
})
```

Set any keymap to `false` to disable it.

## How it works

fm.nvim shells out to:

```bash
fm respond --model system --instructions '…' --stream \
  --save-transcript ~/.cache/nvim/fm.nvim/session-<pid>.json \
  [--resume …] 'your prompt'
```

Follow-up turns resume the saved transcript so the on-device model keeps context. Selection asks pass the selected text with `--text`.

## Health check

```vim
:checkhealth fm
```

## License

MIT
