-- Customize Treesitter

-- Add Nix-provided treesitter grammars to runtimepath
local nix_ts_path = vim.env.NVIM_TREESITTER_PATH
if nix_ts_path and nix_ts_path ~= "" then
  vim.opt.runtimepath:append(nix_ts_path)
end

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
