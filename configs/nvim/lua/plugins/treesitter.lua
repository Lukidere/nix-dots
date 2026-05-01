-- Customize Treesitter

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    treesitter = {
      highlight = true,
      indent = true,
      auto_install = false, -- NixOS: parsers come from Nix, not runtime downloads
      ensure_installed = {
        "lua", "vim", "vimdoc",
        "rust",
        "python",
        "nix",
        "bash",
        "javascript", "typescript", "tsx",
        "json", "yaml", "toml",
        "markdown", "markdown_inline",
        "regex",
      },
    },
  },
}
