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
