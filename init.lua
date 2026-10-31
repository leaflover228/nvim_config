-- ─────────────────────────────────────────────────────────────
-- Options
-- ─────────────────────────────────────────────────────────────
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local o = vim.opt
o.number = true
o.relativenumber = true
o.mouse = "a"
o.showmode = false
o.clipboard = "unnamedplus"
o.breakindent = true
o.undofile = true
o.ignorecase = true
o.smartcase = true
o.signcolumn = "yes"
o.updatetime = 250
o.timeoutlen = 400
o.splitright = true
o.splitbelow = true
o.list = true
o.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
o.inccommand = "split"
o.cursorline = true
o.scrolloff = 8
o.termguicolors = true
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4
o.softtabstop = 4
o.confirm = true
o.winborder = "rounded"

local map = vim.keymap.set

-- ─────────────────────────────────────────────────────────────
-- Basic keymaps
-- ─────────────────────────────────────────────────────────────
map("n", "<Esc>", "<cmd>nohlsearch<CR>")
map("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Diagnostics to loclist" })
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.hl.on_yank() end,
})

-- ─────────────────────────────────────────────────────────────
-- Window navigation between editor and terminal
--   Ctrl+h/j/k/l : normal mode and terminal mode
--   Alt+h/j/k/l  : normal, insert and terminal mode
--   (if Alt does not work on macOS, enable "Option as Meta" in your terminal)
-- Entering a terminal window automatically switches to insert mode, so you
-- can type right away. Leave a terminal with Ctrl/Alt+hjkl or Esc Esc.
-- ─────────────────────────────────────────────────────────────
for _, k in ipairs({ "h", "j", "k", "l" }) do
  map("n", "<C-" .. k .. ">", "<C-w>" .. k, { desc = "Window " .. k })
  map("t", "<C-" .. k .. ">", "<C-\\><C-n><C-w>" .. k, { desc = "Window " .. k })
  map("n", "<A-" .. k .. ">", "<C-w>" .. k, { desc = "Window " .. k })
  map("i", "<A-" .. k .. ">", "<Esc><C-w>" .. k, { desc = "Window " .. k })
  map("t", "<A-" .. k .. ">", "<C-\\><C-n><C-w>" .. k, { desc = "Window " .. k })
end
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- ─────────────────────────────────────────────────────────────
-- Terminals
-- ─────────────────────────────────────────────────────────────
vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
    vim.opt_local.scrolloff = 0
  end,
})

-- Auto insert mode whenever you enter a terminal window
vim.api.nvim_create_autocmd({ "TermOpen", "BufEnter", "WinEnter" }, {
  callback = function()
    if vim.bo.buftype == "terminal" then
      vim.cmd.startinsert()
    end
  end,
})

-- One persistent bottom terminal you can show/hide with <leader>tt
local bottom_term = { buf = nil, win = nil }
local function toggle_bottom_term()
  if bottom_term.win and vim.api.nvim_win_is_valid(bottom_term.win) then
    vim.api.nvim_win_hide(bottom_term.win)
    bottom_term.win = nil
    return
  end
  vim.cmd("botright 15split")
  bottom_term.win = vim.api.nvim_get_current_win()
  if bottom_term.buf and vim.api.nvim_buf_is_valid(bottom_term.buf) then
    vim.api.nvim_win_set_buf(bottom_term.win, bottom_term.buf)
  else
    vim.cmd.terminal()
    bottom_term.buf = vim.api.nvim_get_current_buf()
  end
  vim.cmd.startinsert()
end

-- When the shell in that terminal exits, forget it and close its window
vim.api.nvim_create_autocmd("TermClose", {
  callback = function(ev)
    if ev.buf == bottom_term.buf then
      bottom_term.buf = nil
      bottom_term.win = nil
      vim.schedule(function() pcall(vim.api.nvim_buf_delete, ev.buf, { force = true }) end)
    end
  end,
})

map("n", "<leader>tt", toggle_bottom_term, { desc = "Toggle bottom terminal" })
map("n", "<leader>tv", "<cmd>vsplit | terminal<CR>", { desc = "Terminal (right split)" })

-- ─────────────────────────────────────────────────────────────
-- Build (:make + quickfix) and run
-- ─────────────────────────────────────────────────────────────
vim.api.nvim_create_autocmd("FileType", {
  pattern = "rust",
  callback = function() vim.cmd.compiler("cargo") end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "cpp" },
  callback = function(ev)
    if vim.fn.filereadable("CMakeLists.txt") == 1 then
      vim.opt_local.makeprg = "cmake --build build"
    else
      vim.opt_local.makeprg = "make"
    end

    -- Compile and run just this one file (no build system needed)
    map("n", "<leader>rf", function()
      vim.cmd("write")
      local src = vim.fn.shellescape(vim.fn.expand("%:p"))
      local out = vim.fn.shellescape(vim.fn.expand("%:p:r"))
      local cc = vim.bo.filetype == "c" and "gcc" or "g++ -std=c++20"
      vim.cmd("botright 15split")
      vim.cmd.terminal(string.format("%s -Wall -Wextra -g %s -o %s && %s", cc, src, out, out))
    end, { buffer = ev.buf, desc = "Compile and run this file" })
  end,
})

-- Build, and open the error list only if there are errors
map("n", "<leader>mm", "<cmd>silent make | cwindow | redraw!<CR>", { desc = "Build (quickfix)" })
map("n", "<leader>mo", "<cmd>copen<CR>", { desc = "Open quickfix" })
map("n", "<leader>mc", "<cmd>cclose<CR>", { desc = "Close quickfix" })
-- ]q / [q jump to next/previous error (built into Neovim)

-- ─────────────────────────────────────────────────────────────
-- Rust config (must be set BEFORE rustaceanvim loads)
-- ─────────────────────────────────────────────────────────────
local mason_pkgs = vim.fn.stdpath("data") .. "/mason/packages"

vim.g.rustaceanvim = function()
  local codelldb = mason_pkgs .. "/codelldb/extension/adapter/codelldb"
  local liblldb = mason_pkgs
    .. "/codelldb/extension/lldb/lib/liblldb"
    .. (vim.uv.os_uname().sysname == "Darwin" and ".dylib" or ".so")

  local cfg = require("rustaceanvim.config")
  return {
    tools = {
      float_win_config = { border = "rounded" },
    },
    server = {
      default_settings = {
        ["rust-analyzer"] = {
          check = { command = "clippy" },
          cargo = { features = "all" },
          procMacro = { enable = true },
          inlayHints = {
            closingBraceHints = { minLines = 20 },
            lifetimeElisionHints = { enable = "skip_trivial" },
          },
        },
      },
    },
    dap = {
      adapter = vim.uv.fs_stat(codelldb) and cfg.get_codelldb_adapter(codelldb, liblldb) or nil,
    },
  }
end

-- ─────────────────────────────────────────────────────────────
-- Bootstrap lazy.nvim
-- ─────────────────────────────────────────────────────────────
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
  if vim.v.shell_error ~= 0 then
    error("Failed to clone lazy.nvim:\n" .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

-- ─────────────────────────────────────────────────────────────
-- Plugins
-- ─────────────────────────────────────────────────────────────
require("lazy").setup({

  -- ── UI ─────────────────────────────────────────────────────
  {
    "folke/tokyonight.nvim",
    priority = 1000,
    config = function() vim.cmd.colorscheme("tokyonight-night") end,
  },
  { "nvim-lualine/lualine.nvim", opts = { options = { theme = "tokyonight" } } },
  { "j-hui/fidget.nvim", opts = {} }, -- shows rust-analyzer / clangd indexing progress
  { "lewis6991/gitsigns.nvim", opts = {} },

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      spec = {
        { "<leader>s", group = "search" },
        { "<leader>r", group = "rust / run" },
        { "<leader>d", group = "debug" },
        { "<leader>t", group = "terminal / toggle" },
        { "<leader>m", group = "make" },
        { "<leader>n", group = "tests (neotest)" },
        { "<leader>x", group = "diagnostics" },
        { "<leader>c", group = "code / crates" },
      },
    },
  },

  -- Floating terminal: Ctrl+\ (2<C-\> opens a second one)
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    opts = { open_mapping = [[<C-\>]], direction = "float", float_opts = { border = "curved" } },
  },

  -- File explorer as a buffer (press - to open)
  {
    "stevearc/oil.nvim",
    opts = { view_options = { show_hidden = true } },
    keys = { { "-", "<cmd>Oil<CR>", desc = "Open parent directory" } },
  },

  -- ── Editing helpers ────────────────────────────────────────
  { "windwp/nvim-autopairs", event = "InsertEnter", opts = {} },
  { "kylechui/nvim-surround", version = "*", event = "VeryLazy", opts = {} }, -- ys, ds, cs

  -- Jump anywhere on screen: press s then 2 letters (much faster than hjkl)
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash jump" },
      { "S", mode = { "n", "o" }, function() require("flash").treesitter() end, desc = "Flash treesitter" },
    },
  },

  -- Symbol outline sidebar
  {
    "stevearc/aerial.nvim",
    opts = {},
    keys = { { "<leader>o", "<cmd>AerialToggle!<CR>", desc = "Outline" } },
  },

  -- ── Treesitter (main branch, requires tree-sitter-cli) ─────
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").install({
        "c", "cpp", "rust", "lua", "vim", "vimdoc",
        "cmake", "make", "toml", "ron", "json", "yaml", "markdown", "bash",
      })
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          if pcall(vim.treesitter.start, args.buf) then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },

  -- ── Mason: LSP servers, debuggers, formatters ──────────────
  { "mason-org/mason.nvim", opts = {} },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      ensure_installed = {
        "clangd",
        "codelldb",
        "clang-format",
        "lua-language-server",
        "stylua",
        "taplo", -- Cargo.toml / TOML language server
      },
    },
  },

  -- ── LSP ────────────────────────────────────────────────────
  {
    "neovim/nvim-lspconfig",
    dependencies = { "saghen/blink.cmp" },
    config = function()
      vim.lsp.config("*", {
        capabilities = require("blink.cmp").get_lsp_capabilities(),
      })

      vim.lsp.config("clangd", {
        cmd = {
          "clangd",
          "--background-index",
          "--clang-tidy",
          "--header-insertion=iwyu",
          "--completion-style=detailed",
          "--function-arg-placeholders=true",
          "--fallback-style=llvm",
        },
      })

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
            diagnostics = { globals = { "vim" } },
            telemetry = { enable = false },
          },
        },
      })

      -- NOTE: rust-analyzer is handled by rustaceanvim, do NOT enable it here.
      vim.lsp.enable({ "clangd", "lua_ls", "taplo" })

      vim.diagnostic.config({
        severity_sort = true,
        float = { border = "rounded", source = "if_many" },
        virtual_text = { spacing = 2, prefix = "●" },
        signs = true,
      })

      -- Neovim already gives you: K, grn, gra, grr, gri, gO, <C-s>
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local client = vim.lsp.get_client_by_id(ev.data.client_id)
          local function bmap(mode, lhs, rhs, desc)
            map(mode, lhs, rhs, { buffer = ev.buf, desc = "LSP: " .. desc })
          end

          bmap("n", "gd", vim.lsp.buf.definition, "Go to definition")
          bmap("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
          bmap("n", "gy", vim.lsp.buf.type_definition, "Go to type definition")
          bmap("n", "<leader>e", vim.diagnostic.open_float, "Line diagnostics")
          bmap("n", "<leader>th", function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
          end, "Toggle inlay hints")

          if client and client.name == "clangd" then
            bmap("n", "<leader>ch", "<cmd>LspClangdSwitchSourceHeader<CR>", "Switch source/header")
          end

          if client and client:supports_method("textDocument/inlayHint") then
            vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
          end
        end,
      })
    end,
  },

  -- ── Rust ───────────────────────────────────────────────────
  {
    "mrcjkb/rustaceanvim",
    version = "^9", -- if lazy cannot resolve this, change to "^8"
    lazy = false, -- the plugin is already lazy by filetype
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "rust",
        callback = function(ev)
          local function bmap(lhs, cmd, desc)
            map("n", lhs, function() vim.cmd.RustLsp(cmd) end, { buffer = ev.buf, desc = "Rust: " .. desc })
          end
          bmap("K", { "hover", "actions" }, "Hover actions")
          bmap("<leader>ra", "codeAction", "Code action")
          bmap("<leader>rr", "runnables", "Runnables")
          bmap("<leader>rd", "debuggables", "Debuggables")
          bmap("<leader>rt", "testables", "Testables")
          bmap("<leader>rm", "expandMacro", "Expand macro")
          bmap("<leader>rc", "openCargo", "Open Cargo.toml")
          bmap("<leader>rp", "parentModule", "Parent module")
          bmap("<leader>re", "explainError", "Explain error")
          bmap("<leader>rE", "renderDiagnostic", "Render diagnostic")
          bmap("<leader>rw", "reloadWorkspace", "Reload workspace")
          bmap("J", "joinLines", "Join lines")
        end,
      })
    end,
  },

  -- Cargo.toml: crate versions inline, completion, hover and code actions
  {
    "saecki/crates.nvim",
    tag = "stable",
    event = "BufRead Cargo.toml",
    opts = {
      lsp = { enabled = true, actions = true, completion = true, hover = true },
    },
    keys = {
      { "<leader>cv", function() require("crates").show_versions_popup() end, desc = "Crate versions" },
      { "<leader>cf", function() require("crates").show_features_popup() end, desc = "Crate features" },
      { "<leader>cu", function() require("crates").upgrade_crate() end, desc = "Upgrade crate" },
      { "<leader>cU", function() require("crates").upgrade_all_crates() end, desc = "Upgrade all crates" },
    },
  },

  -- Tests with a summary panel. Uses rustaceanvim's adapter
  -- (do not install neotest-rust alongside it). Works with cargo or cargo-nextest.
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "mrcjkb/rustaceanvim",
    },
    keys = {
      { "<leader>nn", function() require("neotest").run.run() end, desc = "Test nearest" },
      { "<leader>nf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Test file" },
      { "<leader>na", function() require("neotest").run.run({ suite = true }) end, desc = "Test whole crate" },
      { "<leader>nd", function() require("neotest").run.run({ strategy = "dap" }) end, desc = "Debug nearest test" },
      { "<leader>nl", function() require("neotest").run.run_last() end, desc = "Run last test" },
      { "<leader>ns", function() require("neotest").summary.toggle() end, desc = "Test summary" },
      { "<leader>no", function() require("neotest").output.open({ enter = true }) end, desc = "Test output" },
      { "<leader>nO", function() require("neotest").output_panel.toggle() end, desc = "Test output panel" },
    },
    config = function()
      require("neotest").setup({
        adapters = { require("rustaceanvim.neotest") },
      })
    end,
  },

  -- ── Completion ─────────────────────────────────────────────
  {
    "saghen/blink.cmp",
    version = "1.*", -- v2 is still under development
    opts = {
      keymap = { preset = "default" }, -- <C-y> accept, <C-n>/<C-p> select, <C-space> docs
      appearance = { nerd_font_variant = "mono" },
      completion = { documentation = { auto_show = true, auto_show_delay_ms = 300 } },
      sources = { default = { "lsp", "path", "snippets", "buffer" } },
      signature = { enabled = true },
    },
  },

  -- ── Formatting ─────────────────────────────────────────────
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    keys = {
      {
        "<leader>f",
        function() require("conform").format({ async = true, lsp_format = "fallback" }) end,
        desc = "Format buffer",
      },
    },
    opts = {
      formatters_by_ft = {
        c = { "clang-format" },
        cpp = { "clang-format" },
        rust = { "rustfmt" },
        lua = { "stylua" },
        toml = { lsp_format = "prefer" }, -- taplo
      },
      format_on_save = { timeout_ms = 1000, lsp_format = "fallback" },
    },
  },

  -- ── Fuzzy finder ───────────────────────────────────────────
  {
    "nvim-telescope/telescope.nvim",
    branch = "master",
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond = function() return vim.fn.executable("make") == 1 end,
      },
    },
    config = function()
      local telescope = require("telescope")
      telescope.setup({})
      pcall(telescope.load_extension, "fzf")

      local b = require("telescope.builtin")
      map("n", "<leader>sf", b.find_files, { desc = "Search files" })
      map("n", "<leader>sg", b.live_grep, { desc = "Search by grep" })
      map("n", "<leader>sw", b.grep_string, { desc = "Search word under cursor" })
      map("n", "<leader>sb", b.buffers, { desc = "Search buffers" })
      map("n", "<leader>sh", b.help_tags, { desc = "Search help" })
      map("n", "<leader>sd", b.diagnostics, { desc = "Search diagnostics" })
      map("n", "<leader>sr", b.resume, { desc = "Resume last search" })
      map("n", "<leader>ss", b.lsp_document_symbols, { desc = "Document symbols" })
      map("n", "<leader>sS", b.lsp_dynamic_workspace_symbols, { desc = "Workspace symbols" })
      map("n", "<leader>/", b.current_buffer_fuzzy_find, { desc = "Fuzzy search in buffer" })
    end,
  },

  -- ── Diagnostics list ───────────────────────────────────────
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {},
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>", desc = "Diagnostics (Trouble)" },
      { "<leader>xb", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", desc = "Buffer diagnostics" },
    },
  },

  -- ── Debugging (C/C++ here, Rust via rustaceanvim) ──────────
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "theHamsta/nvim-dap-virtual-text",
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup()
      require("nvim-dap-virtual-text").setup()

      dap.listeners.after.event_initialized["dapui"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui"] = function() dapui.close() end

      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = mason_pkgs .. "/codelldb/extension/adapter/codelldb",
          args = { "--port", "${port}" },
        },
      }

      dap.configurations.cpp = {
        {
          name = "Launch executable",
          type = "codelldb",
          request = "launch",
          program = function()
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
        },
      }
      dap.configurations.c = dap.configurations.cpp
      -- Rust: use <leader>rd (:RustLsp debuggables) or <leader>nd (debug nearest test)

      map("n", "<F5>", dap.continue, { desc = "DAP: Continue" })
      map("n", "<F10>", dap.step_over, { desc = "DAP: Step over" })
      map("n", "<F11>", dap.step_into, { desc = "DAP: Step into" })
      map("n", "<F12>", dap.step_out, { desc = "DAP: Step out" })
      map("n", "<leader>db", dap.toggle_breakpoint, { desc = "DAP: Toggle breakpoint" })
      map("n", "<leader>dB", function()
        dap.set_breakpoint(vim.fn.input("Condition: "))
      end, { desc = "DAP: Conditional breakpoint" })
      map("n", "<leader>du", dapui.toggle, { desc = "DAP: Toggle UI" })
      map("n", "<leader>dr", dap.repl.open, { desc = "DAP: REPL" })
      map("n", "<leader>dx", dap.terminate, { desc = "DAP: Terminate" })
    end,
  },

}, {
  ui = { border = "rounded" },
  checker = { enabled = false },
})
