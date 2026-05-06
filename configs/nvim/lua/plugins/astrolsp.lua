
-- AstroLSP allows you to customize the features in AstroNvim's LSP configuration engine
-- Configuration documentation can be found with `:h astrolsp`

---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@type AstroLSPOpts
  opts = {
    features = {
      codelens = true,
      inlay_hints = true,
      semantic_tokens = true,
    },
    formatting = {
      format_on_save = {
        enabled = true,
        allow_filetypes = {},
        ignore_filetypes = {},
      },
      disabled = {},
      timeout_ms = 1000,
    },
    -- NixOS: all LSPs installed via Nix, not Mason
    servers = {
      "rust_analyzer",
      "pyright",
      "nixd",
      "bashls",
      "ts_ls",
      "lua_ls",
    },
    config = {
      rust_analyzer = {
        cmd = { "rust-analyzer" },
        settings = {
          ["rust-analyzer"] = {
            checkOnSave = { command = "clippy" },
            inlayHints = {
              bindingModeHints = { enable = true },
              chainingHints = { enable = true },
              closingBraceHints = { enable = true },
              parameterHints = { enable = true },
              typeHints = { enable = true },
            },
          },
        },
      },
      nixd = {
        cmd = { "nixd" },
        settings = {
          nixd = {
            nixpkgs = { expr = "import <nixpkgs> {}" },
            formatting = { command = { "nixfmt" } },
          },
        },
      },
      bashls = { cmd = { "bash-language-server", "start" } },
      pyright = { cmd = { "pyright-langserver", "--stdio" } },
      ts_ls = { cmd = { "typescript-language-server", "--stdio" } },
    },
    handlers = {
      rnix = false, -- disabled: using nixd instead (astrocommunity.pack.nix enables rnix by default)
    },
    autocmds = {
      lsp_codelens_refresh = {
        cond = "textDocument/codeLens",
        {
          event = { "InsertLeave", "BufEnter" },
          desc = "Refresh codelens (buffer)",
          callback = function(args)
            if require("astrolsp").config.features.codelens then
              if vim.lsp.codelens.refresh then
                vim.lsp.codelens.refresh { bufnr = args.buf }
              end
            end
          end,
        },
      },
    },
    mappings = {
      n = {
        gD = {
          function() vim.lsp.buf.declaration() end,
          desc = "Declaration of current symbol",
          cond = "textDocument/declaration",
        },
        ["<Leader>uY"] = {
          function() require("astrolsp.toggles").buffer_semantic_tokens() end,
          desc = "Toggle LSP semantic highlight (buffer)",
          cond = function(client)
            return client:supports_method "textDocument/semanticTokens/full"
              and vim.lsp.semantic_tokens ~= nil
          end,
        },
      },
    },
    on_attach = function(client, bufnr) end,
  },
}
