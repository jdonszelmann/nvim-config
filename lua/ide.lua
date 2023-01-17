-- ============= Treesitter ===============
--
require 'nvim-treesitter.configs'.setup {
    -- A list of parser names, or "all"
    ensure_installed = {
        "rust", "toml",

        "javascript", "css", "scss", "html", "typescript", "markdown", "json",

        "bash",
        "regex",
        "dockerfile",
        "yaml",
        "go", "gomod",
        "lua",
        "python",
        "vim",

        "c", "cpp", "cmake",

        "git_rebase", "gitattributes", "gitcommit", "gitignore",
    },

    highlight = {
        enable = true,
        additional_vim_regex_highlighting = true,
    },

    autotag = {
        enable = true,
    }
}

require("vim.treesitter.query").set_query("rust", "injections", [[
(
 (line_comment) @_first 
 (_) @rust
 (line_comment) @_last 
 (#match? @_first "^/// ```$") 
 (#match? @_last "^/// ```$")
 (#offset! @rust 0 4 0 4)
)
]])

require 'nvim-treesitter.configs'.setup {
    textobjects = {
        select = {
            enable = true,
            keymaps = {
                ["af"] = "@function.outer",
                ["if"] = "@function.inner",
                ["ac"] = "@comment.outer",
                ["ib"] = "@block.inner",
                ["ab"] = "@block.outer",
                ["ip"] = "@parameter.inner",
                ["ap"] = "@parameter.outer",
            },
            selection_modes = {
                ['@parameter.outer'] = 'v', -- charwise
                ['@function.outer'] = 'V', -- linewise
                ['@class.outer'] = 'V', -- linewise
                ['@block.outer'] = 'v', -- linewise

                ['@parameter.inner'] = 'v', -- charwise
                ['@function.inner'] = 'V', -- linewise
                ['@class.inner'] = 'V', -- linewise
                ['@block.inner'] = 'v', -- linewise

                ['@comment.outer'] = 'v', -- charwise
            },
            include_surrounding_whitespace = true,
        },
    },
}


-- ============= Telescope ===============

require('telescope').setup {
    find_files = {
        find_command = { "fd", "--type", "f", "--strip-cwd-prefix" }
    },
}

local builtin = require('telescope.builtin')
local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local previewers = require('telescope.previewers')
local make_entry = require("telescope.make_entry")
local actions = require("telescope.actions")
local conf = require("telescope.config").values
local action_state = require("telescope.actions.state")

local function find_project_files()
    local opts = {} -- define here if you want to define something
    vim.fn.system('git rev-parse --is-inside-work-tree')
    if vim.v.shell_error == 0 then
        builtin.git_files(opts)
    else
        builtin.find_files(opts)
    end
end

local function find_all_project_files()
    local opts = {
        find_command = {
            'rg',
            '--color=never',
            '--files',
            '-u'
        }
    } -- define here if you want to define something
    builtin.find_files(opts)
end

local function menu(title, objs)
    local opts = {}

    opts.bufnr = vim.api.nvim_get_current_buf()
    opts.winnr = vim.api.nvim_get_current_win()
    pickers
        .new(opts, {
            prompt_title = title,
            finder = finders.new_table {
                results = objs,
                entry_maker = function(entry)
                    return make_entry.set_default_entry_mt({
                        value = entry,
                        text = entry.text,
                        display = entry.text,
                        ordinal = entry.text,
                        filename = entry.filename,
                        func = entry.func,
                    }, opts)
                end,
            },
            previewer = previewers.builtin.new(opts),
            sorter = conf.generic_sorter(opts),
            attach_mappings = function(_)
                actions.select_default:replace(function(prompt_bufnr)
                    local selection = action_state.get_selected_entry()
                    if not selection then
                        utils.__warn_no_selection "builtin.builtin"
                        return
                    end

                    -- we do this to avoid any surprises
                    opts.include_extensions = nil

                    local picker_opts
                    if not opts.use_default_opts then
                        picker_opts = opts
                    end

                    actions.close(prompt_bufnr)
                    -- Call appropriate telescope builtin
                    selection.func(picker_opts)
                end)
                return true
            end,
        })
        :find()
end

local function on_generate_results(results)
    local objs = {}

    for client_id, result in pairs(results) do
        for _, action in pairs(result.result or {}) do
            table.insert(objs, {
                filename = "",
                text = string.gsub(action.title, "[\n\r]+", " "),
                func = function()
                    local client = vim.lsp.get_client_by_id(client_id)

                    local code_action_provider = nil
                    if vim.fn.has("nvim-0.8.0") then
                        code_action_provider = client.server_capabilities.codeActionProvider
                    else
                        code_action_provider = client.resolved_capabilities.code_action
                    end

                    local apply_action = require("rust-tools").code_action_group.apply_action

                    if not action.edit
                        and client
                        and type(code_action_provider) == "table"
                        and code_action_provider.resolveProvider
                    then
                        client.request("codeAction/resolve", action, function(err, resolved_action)
                            if err then
                                vim.notify(err.code .. ": " .. err.message, vim.log.levels.ERROR)
                                return
                            end
                            apply_action(resolved_action, client, {})
                        end)
                    else
                        apply_action({
                            client_id,
                            action,
                        }, client, {})
                    end
                end
            })
        end
    end
    if #objs == 0 then
        vim.notify("No code actions available", vim.log.levels.INFO)
        return
    end

    menu("Code Actions", objs)
end

local function generate()
    local context = {}
    context.diagnostics = vim.lsp.diagnostic.get_line_diagnostics()
    local params = vim.lsp.util.make_range_params()
    params.context = context

    vim.lsp.buf_request_all(
        0,
        "textDocument/codeAction",
        params,
        function(results)
            on_generate_results(results)
        end
    )
end

local function run_godbolt(compiler, flags, output)
    local cmd = "compiler=" .. compiler
    vim.g.last_godbolt = cmd
    vim.cmd("CECompile " .. cmd)
end

local function godbolt_opt_level(next)
    local objs = {
        { filename = "", text = "opt-level 0", func = function() next("0") end },
        { filename = "", text = "opt-level 1", func = function() next("1") end },
        { filename = "", text = "opt-level 2", func = function() next("2") end },
        { filename = "", text = "opt-level 3", func = function() next("3") end },
        { filename = "", text = "opt-level s", func = function() next("s") end },
        { filename = "", text = "opt-level z", func = function() next("z") end },
    }

    menu("Godbolt Optimization Level", objs)
end

local function godbolt_output(compiler, flags)
    local objs = {
        { filename = "", text = "intel assembly", func = function() run_godbolt(compiler, flags, "") end },
        { filename = "", text = "at&t assembly",
            func = function() run_godbolt(compiler, flags, "binary=true intel=false") end },
        { filename = "", text = "binary", func = function() run_godbolt(compiler, flags, "binary=true") end },
    }

    menu("Godbolt Output", objs)
end

local function godbolt_c_compiler(compiler)
    godbolt_opt_level(function(level)
        godbolt_output(compiler, "-O" .. level)
    end)
end

local function godbolt_rust_compiler(compiler)
    godbolt_opt_level(function(level)
        godbolt_output(compiler, "-Copt-level=" .. level)
    end)
end

local function last_godbolt()
    return vim.inspect(vim.g.last_godbolt)
end

local function run_last_godbolt()
    local cmd = last_godbolt()
    print("CECompile " .. cmd)
end

local function godbolt()
    local objs = {
        { filename = "", text = "gcc", func = function() godbolt_c_compiler("gcc") end },
        { filename = "", text = "rust nightly", func = function() godbolt_rust_compiler("nightly") end },
        { filename = "", text = "rust beta", func = function() godbolt_rust_compiler("beta") end },
        { filename = "", text = "rust stable", func = function() godbolt_rust_compiler("r1660") end },
        { filename = "", text = "g++", func = function() godbolt_c_compiler("g++") end },
    }

    if not (last_godbolt() == "" or last_godbolt() == nil) then
        table.insert(objs,
            { filename = "", text = "previous: " .. last_godbolt(), func = function() run_last_godbolt() end })
    end

    menu("Godbolt Language", objs)
end

local function useful_pickers()
    local objs = {}
    local include_names = {
        ["grep_string"] = "find other occurences of selected string",
        ["help_tags"] = { [0] = "documentation", [1] = require("rust-tools").hover_actions.hover_actions },
        ["live_grep"] = "find in files",
        ["find_files"] = { [0] = "find filename", [1] = find_project_files },
        ["quickfix"] = { [0] = "generate", [1] = generate },
        ["marks"] = { [0] = "run", [1] = require("rust-tools").runnables.runnables },
        ["git_commits"] = "commits",
        ["lsp_references"] = "find references",
        ["lsp_implementations"] = "find implementations",
        ["lsp_definitions"] = "find definitions",
        ["lsp_type_definitions"] = "find type definitions",
        ["lsp_incoming_calls"] = "find incoming calls",
        ["lsp_outgoing_calls"] = "find outgoing calls",
        ["treesitter"] = "list symbols",
        ["highlights"] = { [0] = "hover", [1] = require("rust-tools").hover_actions.hover_actions },
        ["jumplist"] = { [0] = "expand macro", [1] = require("rust-tools").expand_macro.expand_macro },
        ["symbols"] = "(emoji) symbols",
        ["git_stash"] = { [0] = "godbolt", [1] = godbolt },
    }

    for k, _ in pairs(builtin) do
        local tab = include_names[k]
        if tab ~= nil then
            if type(tab) == "string" then
                tab = { [0] = tab }
            end

            local func = require("telescope.builtin")[k]

            local count = 0
            for _ in pairs(tab) do count = count + 1 end
            if count == 2 then
                func = tab[1]
            end

            table.insert(objs, {
                filename = "",
                text = tab[0],
                func = func,
            })
        end
    end

    menu("Telescope Pickers", objs)
end

vim.keymap.set('n', '<C-p>', find_project_files, {})
vim.keymap.set('n', '<C-P>', find_all_project_files, {})
vim.keymap.set('n', '<C-g>', builtin.builtin, {})
vim.keymap.set({ 'n', 'i' }, '<C-f>', useful_pickers, {})

vim.keymap.set('n', 'gr', builtin.lsp_references, {})
vim.keymap.set('n', 'gd', builtin.lsp_definitions, {})
vim.keymap.set('n', 'gi', builtin.lsp_implementations, {})


-- ============= Comment ===============

local opts = { noremap = true, silent = true }
local keymap = vim.api.nvim_set_keymap
keymap("n", "<C-_>", ":lua require('Comment.api').toggle.linewise.current()<CR> j", opts)

-- ============= Autocomplete and Snippets =============

local cmp = require 'cmp'

cmp.setup({
    snippet = {
        expand = function(args)
            vim.fn["vsnip#anonymous"](args.body)
        end,
    },
    window = {
        completion = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
    },
    mapping = cmp.mapping.preset.insert({
        ['<C-b>'] = cmp.mapping.scroll_docs(-4),
        ['<C-f>'] = cmp.mapping.scroll_docs(4),
        ['<C-Space>'] = cmp.mapping.complete(),
        ['<C-e>'] = cmp.mapping.abort(),
        -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
        ['<CR>'] = cmp.mapping.confirm({ select = true }),
    }),
    sources = cmp.config.sources({
        { name = 'nvim_lsp' },
        { name = 'vsnip' },
    }, {
        { name = 'buffer' },
    })
})

-- Set configuration for specific filetype.
cmp.setup.filetype('gitcommit', {
    sources = cmp.config.sources({
        { name = 'cmp_git' }, -- You can specify the `cmp_git` source if you were installed it.
    }, {
        { name = 'buffer' },
    })
})

-- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline({ '/', '?' }, {
    mapping = cmp.mapping.preset.cmdline(),
    sources = {
        { name = 'buffer' }
    }
})

-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline(':', {
    mapping = cmp.mapping.preset.cmdline(),
    sources = cmp.config.sources({
        { name = 'path' }
    }, {
        { name = 'cmdline' }
    })
})

require("nvim-autopairs").setup()
local cmp_autopairs = require('nvim-autopairs.completion.cmp')
cmp.event:on(
    'confirm_done',
    cmp_autopairs.on_confirm_done()
)

-- Set up lspconfig.
local capabilities = require('cmp_nvim_lsp').default_capabilities()

-- ============= LSP ===============

-- formatting
require("lsp-format").setup {}
local on_attach = function(client)
    require("lsp-format").on_attach(client)
end

require 'lspconfig'.rust_analyzer.setup { on_attach = on_attach, capabilities = capabilities }
require 'lspconfig'.sumneko_lua.setup {
    on_attach = on_attach, capabilities = capabilities,
    settings = {
        Lua = {
            runtime = {
                -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
                version = 'LuaJIT',
            },
            diagnostics = {
                -- Get the language server to recognize the `vim` global
                globals = { 'vim' },
            },
            workspace = {
                -- Make the server aware of Neovim runtime files
                library = vim.api.nvim_get_runtime_file("", true),
            },
            -- Do not send telemetry data containing a randomized but unique identifier
            telemetry = {
                enable = false,
            },
        },
    },
}
require 'lspconfig'.clangd.setup { on_attach = on_attach, capabilities = capabilities }
require 'lspconfig'.pyright.setup { on_attach = on_attach, capabilities = capabilities }


local rt = require("rust-tools")

rt.setup({
    server = {
        on_attach = function(_, bufnr)
            -- Hover actions
            vim.keymap.set("n", "H", rt.hover_actions.hover_actions, { buffer = bufnr })
            vim.keymap.set("n", "K", rt.hover_actions.hover_actions, { buffer = bufnr })
            vim.keymap.set("n", "<C-e>", rt.runnables.runnables, { buffer = bufnr })
            -- Code action groups
            vim.keymap.set("n", "<A-CR>", generate, { buffer = bufnr })
            vim.keymap.set("n", "gm", rt.expand_macro.expand_macro, { buffer = bufnr })
            vim.keymap.set("n", "<S-F6>", rt.ssr.ssr, { buffer = bufnr })
        end,
    },
})
rt.inlay_hints.enable()


-- ============= Floaterm ===============
keymap('n', "t", ":FloatermToggle myfloat<CR>", opts)
keymap('t', "<Esc>", "<C-\\><C-n>:q<CR>", opts)

vim.ui.select = require "popui.ui-overrider"
vim.ui.input = require "popui.input-overrider"

require "fidget".setup {}

-- ============= Compiler Explorer ===============

require("compiler-explorer").setup({
    url = "https://godbolt.org",
    open_qflist = false, -- Open qflist after compile.
    infer_lang = true, -- Try to infer possible language based on file extension.
    binary_hl = "Comment", -- Highlight group for binary extmarks/virtual text.
    autocmd = {
        enable = false, -- Enable assembly to source and source to assembly highlighting.
        hl = "Cursorline", -- Highlight group used for line match highlighting.
    },
    diagnostics = { -- vim.diagnostic.config() options for the ce-diagnostics namespace.
        underline = false,
        virtual_text = false,
        signs = false,
    },
    split = "vsplit", -- How to split the window after the second compile (split/vsplit).
    compiler_flags = "", -- Default flags passed to the compiler.
    job_timeout = 25000, -- Timeout for libuv job in milliseconds.
})


require("nvim-tree").setup({
    sort_by = "case_sensitive",
    view = {
        adaptive_size = true,
        mappings = {
            list = {
                { key = "u", action = "dir_up" },
            },
        },
        side = "right",
        width = 10,
    },
    renderer = {
        group_empty = true,
    },
    filters = {
        dotfiles = true,
    },
})

-- file tree
keymap('n', "<F2>", ":NvimTreeToggle<CR>", opts)

-- tabs
keymap('n', '<A-<>', '<Cmd>BufferPrevious<CR>', opts)
keymap('n', '<A->>', '<Cmd>BufferNext<CR>', opts)
keymap('n', '<A-1>', '<Cmd>BufferGoto 1<CR>', opts)
keymap('n', '<A-2>', '<Cmd>BufferGoto 2<CR>', opts)
keymap('n', '<A-3>', '<Cmd>BufferGoto 3<CR>', opts)
keymap('n', '<A-4>', '<Cmd>BufferGoto 4<CR>', opts)
keymap('n', '<A-5>', '<Cmd>BufferGoto 5<CR>', opts)
keymap('n', '<A-6>', '<Cmd>BufferGoto 6<CR>', opts)
keymap('n', '<A-7>', '<Cmd>BufferGoto 7<CR>', opts)
keymap('n', '<A-8>', '<Cmd>BufferGoto 8<CR>', opts)
keymap('n', '<A-9>', '<Cmd>BufferGoto 9<CR>', opts)
keymap('n', '<A-0>', '<Cmd>BufferLast<CR>', opts)

keymap('n', '<Space>bb', '<Cmd>BufferOrderByBufferNumber<CR>', opts)
keymap('n', '<Space>bd', '<Cmd>BufferOrderByDirectory<CR>', opts)
keymap('n', '<Space>bl', '<Cmd>BufferOrderByLanguage<CR>', opts)
keymap('n', '<Space>bw', '<Cmd>BufferOrderByWindowNumber<CR>', opts)

keymap('n', '<A-c>', '<Cmd>BufferClose<CR>', opts)
keymap('n', '<A-p>', '<Cmd>BufferPin<CR>', opts)

keymap('n', '<Space>ca', '<Cmd>BufferCloseAllButPinned<CR>', opts)
keymap('n', '<Space>cc', '<Cmd>BufferCloseAllButCurrentOrPinned<CR>', opts)



vim.cmd([[
    let g:suda_smart_edit = 1
    filetype plugin indent on
]])
