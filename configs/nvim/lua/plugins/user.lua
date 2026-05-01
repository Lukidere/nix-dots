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
}
