-- Customize Treesitter

-- Add Nix-provided treesitter grammars to runtimepath (path written by home-manager)
pcall(require, "nix-ts-path")

-- Compatibility shim: astrocore calls nvim-treesitter.get_installed() which was removed
-- in newer nvim-treesitter. Patch it to use the current API.
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyLoad",
  once = true,
  callback = function()
    local ok, ts = pcall(require, "nvim-treesitter")
    if ok and ts and not ts.get_installed then
      ts.get_installed = function()
        local ok2, parsers = pcall(require, "nvim-treesitter.parsers")
        if ok2 then return parsers.available_parsers() end
        return {}
      end
    end
  end,
})

---@type LazySpec
return {
  {
    "AstroNvim/astrocore",
    -- function override: community packs append parsers to ensure_installed via
    -- astrocore (e.g. pack.haskell), which triggers broken tree-sitter compiles
    -- on NixOS. A table `= {}` would merge; only a function truly clears it.
    opts = function(_, opts)
      opts.treesitter = opts.treesitter or {}
      opts.treesitter.highlight = true
      opts.treesitter.indent = true
      opts.treesitter.auto_install = false
      opts.treesitter.ensure_installed = {}
    end,
  },
  {
    -- NixOS: grammars come from nix (home.nix treesitterGrammars); community packs
    -- append to ensure_installed which triggers broken tree-sitter compiles - clear it.
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = {}
      opts.auto_install = false
    end,
  },
}
