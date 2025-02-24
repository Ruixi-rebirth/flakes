{ appearance }:
let
  n = appearance.palettes.nord;
  h = appearance.toHex;
in
{
  completion = {
    border = {
      fg = (h n.nord9);
    };
  };
  confirm = {
    border = {
      fg = (h n.nord9);
    };
    btn_labels = [
      "  [Y]es  "
      "  (N)o  "
    ];
    btn_no = { };
    btn_yes = {
      reversed = true;
    };
    title = {
      fg = (h n.nord9);
    };
  };
  filetype = {
    rules = [
      {
        fg = (h n.nord13);
        mime = "image/*";
      }
      {
        fg = (h n.nord15);
        mime = "{audio,video}/*";
      }
      {
        fg = (h n.nord11);
        mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}";
      }
      {
        fg = (h n.nord9);
        mime = "application/{pdf,doc,rtf}";
      }
      {
        bg = (h n.nord11);
        is = "orphan";
        url = "*";
      }
      {
        fg = (h n.nord14);
        is = "exec";
        url = "*";
      }
      {
        fg = (h n.nord9);
        url = "*/";
      }
    ];
  };
  flavor = {
    dark = "";
    light = "";
  };
  help = {
    footer = {
      bg = (h n.nord6);
      fg = (h n.nord1);
    };
    on = {
      fg = (h n.nord9);
    };
    run = {
      fg = (h n.nord15);
    };
  };
  input = {
    border = {
      fg = (h n.nord9);
    };
    selected = {
      reversed = true;
    };
  };
  mgr = {
    border_style = {
      fg = (h n.nord3);
    };
    border_symbol = "│";
    count_copied = {
      bg = (h n.nord14);
      fg = (h n.nord6);
    };
    count_cut = {
      bg = (h n.nord11);
      fg = (h n.nord6);
    };
    count_selected = {
      bg = (h n.nord13);
      fg = (h n.nord6);
    };
    cwd = {
      fg = (h n.nord9);
    };
    find_keyword = {
      bold = true;
      fg = (h n.nord13);
      italic = true;
      underline = true;
    };
    find_position = {
      bg = "reset";
      bold = true;
      fg = (h n.nord15);
      italic = true;
    };
    hovered = {
      bg = (h n.nord2);
      bold = true;
    };
    marker_copied = {
      bg = (h n.nord14);
      fg = (h n.nord14);
    };
    marker_cut = {
      bg = (h n.nord11);
      fg = (h n.nord11);
    };
    marker_marked = {
      bg = (h n.nord9);
      fg = (h n.nord9);
    };
    marker_selected = {
      bg = (h n.nord13);
      fg = (h n.nord13);
    };
    preview_hovered = {
      underline = true;
    };
    syntect_theme = "";
    tab_active = {
      reversed = true;
    };
    tab_width = 1;
  };
  mode = {
    normal_alt = {
      bg = (h n.nord3);
      fg = (h n.nord9);
    };
    normal_main = {
      bg = (h n.nord9);
      bold = true;
    };
    select_alt = {
      bg = (h n.nord3);
      fg = (h n.nord11);
    };
    select_main = {
      bg = (h n.nord11);
      bold = true;
    };
    unset_alt = {
      bg = (h n.nord3);
      fg = (h n.nord11);
    };
    unset_main = {
      bg = (h n.nord11);
      bold = true;
    };
  };
  notify = {
    icon_error = "";
    icon_info = "";
    icon_warn = "";
    title_error = {
      fg = (h n.nord11);
    };
    title_info = {
      fg = (h n.nord14);
    };
    title_warn = {
      fg = (h n.nord13);
    };
  };
  pick = {
    active = {
      bold = true;
      fg = (h n.nord15);
    };
    border = {
      fg = (h n.nord9);
    };
  };
  status = {
    perm_exec = {
      fg = (h n.nord9);
    };
    perm_read = {
      fg = (h n.nord13);
    };
    perm_sep = {
      fg = (h n.nord1);
    };
    perm_type = {
      fg = (h n.nord14);
    };
    perm_write = {
      fg = (h n.nord11);
    };
    progress_error = {
      bg = (h n.nord0);
      fg = (h n.nord11);
    };
    progress_label = {
      bold = true;
    };
    progress_normal = {
      bg = (h n.nord0);
      fg = (h n.nord9);
    };
    separator_close = "";
    separator_open = "";
  };
  tasks = {
    border = {
      fg = (h n.nord9);
    };
    hovered = {
      fg = (h n.nord15);
      underline = true;
    };
  };
  which = {
    cand = {
      fg = (h n.nord9);
    };
    cols = 3;
    desc = {
      fg = (h n.nord15);
    };
    mask = {
      bg = (h n.nord0);
    };
    rest = {
      fg = (h n.nord1);
    };
    separator = "  ";
    separator_style = {
      fg = (h n.nord1);
    };
  };
}
