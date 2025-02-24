{
  completion = {
    border = {
      fg = "#81A1C1";
    };
  };
  confirm = {
    border = {
      fg = "#81A1C1";
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
      fg = "#81A1C1";
    };
  };
  filetype = {
    rules = [
      {
        fg = "#EBCB8B";
        mime = "image/*";
      }
      {
        fg = "#B48EAD";
        mime = "{audio,video}/*";
      }
      {
        fg = "#BF616A";
        mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}";
      }
      {
        fg = "#81A1C1";
        mime = "application/{pdf,doc,rtf}";
      }
      {
        bg = "#BF616A";
        is = "orphan";
        name = "*";
      }
      {
        fg = "#A3BE8C";
        is = "exec";
        name = "*";
      }
      {
        bg = "#BF616A";
        is = "dummy";
        name = "*";
      }
      {
        bg = "#BF616A";
        is = "dummy";
        name = "*/";
      }
      {
        fg = "#81A1C1";
        name = "*/";
      }
    ];
  };
  flavor = {
    dark = "";
    light = "";
  };
  help = {
    footer = {
      bg = "#ECEFF4";
      fg = "#3B4252";
    };
    on = {
      fg = "#81A1C1";
    };
    run = {
      fg = "#B48EAD";
    };
  };
  input = {
    border = {
      fg = "#81A1C1";
    };
    selected = {
      reversed = true;
    };
  };
  mgr = {
    border_style = {
      fg = "#4C566A";
    };
    border_symbol = "│";
    count_copied = {
      bg = "#A3BE8C";
      fg = "#ECEFF4";
    };
    count_cut = {
      bg = "#BF616A";
      fg = "#ECEFF4";
    };
    count_selected = {
      bg = "#EBCB8B";
      fg = "#ECEFF4";
    };
    cwd = {
      fg = "#81A1C1";
    };
    find_keyword = {
      bold = true;
      fg = "#EBCB8B";
      italic = true;
      underline = true;
    };
    find_position = {
      bg = "reset";
      bold = true;
      fg = "#B48EAD";
      italic = true;
    };
    hovered = {
      reversed = true;
    };
    marker_copied = {
      bg = "#A3BE8C";
      fg = "#A3BE8C";
    };
    marker_cut = {
      bg = "#BF616A";
      fg = "#BF616A";
    };
    marker_marked = {
      bg = "#81A1C1";
      fg = "#81A1C1";
    };
    marker_selected = {
      bg = "#EBCB8B";
      fg = "#EBCB8B";
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
      bg = "#4C566A";
      fg = "#81A1C1";
    };
    normal_main = {
      bg = "#81A1C1";
      bold = true;
    };
    select_alt = {
      bg = "#4C566A";
      fg = "#BF616A";
    };
    select_main = {
      bg = "#BF616A";
      bold = true;
    };
    unset_alt = {
      bg = "#4C566A";
      fg = "#BF616A";
    };
    unset_main = {
      bg = "#BF616A";
      bold = true;
    };
  };
  notify = {
    icon_error = "";
    icon_info = "";
    icon_warn = "";
    title_error = {
      fg = "#BF616A";
    };
    title_info = {
      fg = "#A3BE8C";
    };
    title_warn = {
      fg = "#EBCB8B";
    };
  };
  pick = {
    active = {
      bold = true;
      fg = "#B48EAD";
    };
    border = {
      fg = "#81A1C1";
    };
  };
  status = {
    perm_exec = {
      fg = "#81A1C1";
    };
    perm_read = {
      fg = "#EBCB8B";
    };
    perm_sep = {
      fg = "#3B4252";
    };
    perm_type = {
      fg = "#A3BE8C";
    };
    perm_write = {
      fg = "#BF616A";
    };
    progress_error = {
      bg = "#2E3440";
      fg = "#BF616A";
    };
    progress_label = {
      bold = true;
    };
    progress_normal = {
      bg = "#2E3440";
      fg = "#81A1C1";
    };
    separator_close = "";
    separator_open = "";
  };
  tasks = {
    border = {
      fg = "#81A1C1";
    };
    hovered = {
      fg = "#B48EAD";
      underline = true;
    };
  };
  which = {
    cand = {
      fg = "#81A1C1";
    };
    cols = 3;
    desc = {
      fg = "#B48EAD";
    };
    mask = {
      bg = "#2E3440";
    };
    rest = {
      fg = "#3B4252";
    };
    separator = "  ";
    separator_style = {
      fg = "#3B4252";
    };
  };
}
