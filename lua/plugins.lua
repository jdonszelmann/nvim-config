-- You must run this or `PackerSync` whenever you make changes to your plugin configuration
-- Regenerate compiled loader file
-- :PackerCompile

-- Remove any disabled or unused plugins
-- :PackerClean

-- Clean, then install missing plugins
-- :PackerInstall

-- Clean, then update and install plugins
-- supports the `--preview` flag as an optional first argument to preview updates
-- :PackerUpdate

-- Perform `PackerUpdate` and then `PackerCompile`
-- supports the `--preview` flag as an optional first argument to preview updates
-- :PackerSync

-- Show list of installed plugins
-- :PackerStatus

return require('packer').startup(function(use)
    use 'navarasu/onedark.nvim'

    use {
        'nvim-treesitter/nvim-treesitter',
        run = ':TSUpdate'
    }

    use {
        'nvim-treesitter/nvim-treesitter-textobjects',
        run = ':TSUpdate'
    }


    use 'nvim-treesitter/playground'
    use 'neovim/nvim-lspconfig'
    use "j-hui/fidget.nvim"
    use {
        'nvim-telescope/telescope.nvim',
        requires = { { 'nvim-lua/plenary.nvim' } }
    }
    use "desdic/telescope-rooter.nvim"
    use 'nvim-telescope/telescope-symbols.nvim'

    use { 'krady21/compiler-explorer.nvim' }

    use {
        'numToStr/Comment.nvim',
        config = function()
            require('Comment').setup()
        end
    }

    use 'hrsh7th/cmp-nvim-lsp'
    use 'hrsh7th/cmp-buffer'
    use 'hrsh7th/cmp-path'
    use 'hrsh7th/cmp-cmdline'
    use 'hrsh7th/nvim-cmp'
    use 'hrsh7th/cmp-vsnip'
    use 'hrsh7th/vim-vsnip'

    use "lukas-reineke/lsp-format.nvim"

    -- use 'simrat39/rust-tools.nvim'
    use 'mattfbacon/rust-tools.nvim'

    use "nvim-lua/plenary.nvim"
    use 'mfussenegger/nvim-dap'

    use "voldikss/vim-floaterm"

    use "hood/popui.nvim"
    use 'lewis6991/impatient.nvim'

    use 'lambdalisue/suda.vim'
    use({
        "kylechui/nvim-surround",
        config = function()
            require("nvim-surround").setup({
            })
        end
    })

    use {
        "windwp/nvim-autopairs",
        config = function() require("nvim-autopairs").setup {} end
    }
    use "windwp/nvim-ts-autotag"

    use 'nvim-tree/nvim-web-devicons'
    use 'nvim-tree/nvim-tree.lua'
    use 'romgrk/barbar.nvim'
    use 'mg979/vim-visual-multi'
end)
