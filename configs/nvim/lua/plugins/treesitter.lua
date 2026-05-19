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
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    treesitter = {
      highlight = true,
      indent = true,
      auto_install = false,
      ensure_installed = {},
    },
  },
}
