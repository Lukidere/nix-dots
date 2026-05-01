-- Customize Mason

---@type LazySpec
return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = {
      -- NixOS: Mason cannot install tools (dynamic linking incompatibility).
      -- All LSPs and formatters must be provided via Nix packages.
      ensure_installed = {},
    },
  },
}
