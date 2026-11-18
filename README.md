# fm.nvim

Talk to `fm` (Apple Foundation Model CLI) on Neovim.

Type a prompt in a floating window and read the answer in another one. Each prompt is a one-off `fm respond` call: no conversation history yet.

## Requirements

- Neovim 0.10+
- macOS 27+ with Apple Intelligence, and the `fm` CLI on `PATH`
- The `fm` license accepted once per machine: `sudo fm license`

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "hypatia-tile/fm.nvim",
  cmd = "Fm",
  opts = {},
}
```

Or add the repository to `runtimepath` and call `require("fm").setup()`.

## Usage

| Command | Action |
| --- | --- |
| `:Fm` | Open the prompt window |
| `:Fm {prompt}` | Ask directly and show the answer |

In the prompt window, `<CR>` sends the prompt. In Normal mode, `q` or `<Esc>` cancels.

The answer window shows your prompt, then the answer. `q` or `<Esc>` closes it. Closing it while `fm` is still working cancels the request. A new prompt replaces one that is still running.

No keymaps are set. To add one:

```lua
vim.keymap.set("n", "<leader>F", "<cmd>Fm<cr>", { desc = "Ask fm" })
```

## Configuration

```lua
require("fm").setup({
  cmd = "fm",          -- path or name of the fm executable
  instructions = nil,  -- passed to fm with --instructions
})
```

## Development

```sh
make test
```

The tests run headless against a fake `fm`, so they don't need macOS or Apple Intelligence.

The fuller hover chat (multi-turn, streaming, selection context) is parked at the tag `future/hover-chat`. See #2 for what comes back next.

## License

MIT
