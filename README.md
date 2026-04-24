<div align="center">
  <h1>
      <img width="180" alt="icon" src="https://github.com/user-attachments/assets/fced16e1-0c6c-4175-8d38-e1921a82c8ae"/>
      <br/>
      Select Nvim
  </h1>

An opinionated, lightweight replacement for `vim.ui.select`.

</div>

<img height="1024" alt="Screenshot 2025-07-13 at 16 03 28" src="https://github.com/user-attachments/assets/9216b6b8-1653-453b-bfc4-f20027a4e5b1" />

## 🚀 Installation

```lua
{
  "cpea2506/select.nvim",
}
```

### Requirements

- Neovim >= 0.12.0

## ⚙️ Setup

This plugin works immediately after installation.
Configuration is optional, only needed if you want to override defaults.

### Available Options

| Option           | Description                              | Type                 | Notes                             |
| ---------------- | ---------------------------------------- | -------------------- | --------------------------------- |
| `default_prompt` | Default text for the prompt              | `string`             | N/A                               |
| `win_options`    | Window-level Vim options                 | `table<string, any>` | See `:h nvim_win_set_option`      |
| `win_config`     | Window configuration for `nvim_open_win` | `table<string, any>` | See `:h nvim_open_win`            |
| `size_options`   | Dynamic sizing configuration             | `table`              | See [Size Options](#size-options) |

#### Size Options

| Option       | Description                         | Type      | Notes |
| ------------ | ----------------------------------- | --------- | ----- |
| `width.min`  | Minimum width of the select window  | `integer` | N/A   |
| `width.max`  | Maximum width of the select window  | `integer` | N/A   |
| `height.min` | Minimum height of the select window | `integer` | N/A   |
| `height.max` | Maximum height of the select window | `integer` | N/A   |

### Default Configuration

```lua
require("select").setup({
    default_prompt = "Select",
    win_options = {
        cursorline = true,
        cursorlineopt = "both",
        winhighlight = "Normal:FloatNormal,FloatBorder:FloatBorder,CursorLine:Visual",
    },
    win_config = {
        relative = "editor",
        anchor = "NW",
        focusable = false,
        noautocmd = true,
        zindex = 150,
        style = "minimal",
    },
    size_options = {
        width = {
            min = 1,
            max = 80,
        },
        height = {
            min = 1,
            max = 999,
        },
    },
})
```

## ⌨️ Key Mappings

These are the default key mappings:

| Keybinding | Mode(s) | Action                                   |
| ---------- | ------- | ---------------------------------------- |
| `<C-c>`    | n       | Cancel content changes and close select  |
| `q`        | n       | Cancel content changes and close select  |
| `<CR>`     | n       | Confirm content changes and close select |

## 🎨 Highlights

| Highlight Group     | Purpose                           |
| ------------------- | --------------------------------- |
| `SelectOptionLabel` | Option label used to confirm item |

To customize highlights for the plugin window:

```lua
require("select").setup({
  win_options = {
    winhighlight = "NormalFloat:DiagnosticError"
  }
})
```

For more, see `:h winhighlight`.

## 👀 Inspiration

- [dressing.nvim](https://github.com/stevearc/dressing.nvim)
- [clear-action.nvim](https://github.com/luckasRanarison/clear-action.nvim)

## :scroll: Contribution

For detailed instructions on how to contribute to this plugin, please see [the contributing guidelines](CONTRIBUTING.md).
