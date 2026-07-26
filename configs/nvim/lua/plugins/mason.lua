-- Customize Mason
-- NixOS: Mason cannot install tools (dynamic linking incompatibility).
-- All LSPs, DAPs and formatters come from Nix packages. Community packs append
-- to ensure_installed, so each list must be cleared with a function override
-- (a table `ensure_installed = {}` merges and keeps the pack entries).

local function clear(_, opts)
  opts.ensure_installed = {}
  opts.run_on_start = false
end

---@type LazySpec
return {
  { "WhoIsSethDaniel/mason-tool-installer.nvim", opts = clear },
  { "williamboman/mason-lspconfig.nvim", opts = clear, optional = true },
  { "jay-babu/mason-nvim-dap.nvim", opts = clear, optional = true },
}
