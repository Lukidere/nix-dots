return {
  -- 1. Instalujemy wtyczkę neopywal
  {
    "RedsXDD/neopywal.nvim",
    name = "neopywal",
    lazy = false, -- Motyw musi załadować się natychmiast przy starcie
    priority = 1000, -- Bardzo wysoki priorytet, aby załadował się przed UI
    opts = {
      -- Opcjonalnie: przezroczyste tło (true), jeśli używasz przezroczystości w terminalu
      transparent_background = false,
    },
    config = function(_, opts)
      require("neopywal").setup(opts)
      vim.cmd.colorscheme("neopywal")

      -- Live reload: wallust rewrites this file on every wallpaper change, but a
      -- running nvim only reads it at startup - watch it and re-apply the theme.
      local wal = vim.fn.expand("~/.cache/wal/colors-wal.vim")
      local fse = vim.uv.new_fs_event()
      local function watch()
        fse:start(wal, {}, vim.schedule_wrap(function()
          pcall(function()
            package.loaded["neopywal.core"] = nil
            require("neopywal").setup(opts)
            vim.cmd.colorscheme("neopywal")
          end)
          -- editors replace the file (rename), so re-arm the watch on the new inode
          fse:stop()
          vim.defer_fn(watch, 100)
        end))
      end
      if vim.uv.fs_stat(wal) then watch() end
    end,
  },

  -- 2. Informujemy AstroNvim, żeby użył tego motywu jako domyślnego
  {
    "AstroNvim/astroui",
    ---@type AstroUIOpts
    opts = {
      colorscheme = "neopywal",
    },
  },
}
