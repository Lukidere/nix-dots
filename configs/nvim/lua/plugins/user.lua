-- User plugins

---@type LazySpec
return {
  -- Cargo.toml: inline crate versions, update deps, search crates.io
  {
    "saecki/crates.nvim",
    event = { "BufRead Cargo.toml" },
    config = function()
      require("crates").setup {
        completion = {
          cmp = { enabled = true },
        },
      }
    end,
  },
{
  "github/copilot.vim",
  lazy = false,
  priority = 1000,
  config = function()
    vim.g.copilot_no_tab_map = true
    vim.keymap.set("i", "<C-J>", 'copilot#Accept("\\<CR>")', {
      expr = true,
      replace_keycodes = false,
    })
  end,
},
  
}
