{
  mgr = {
    linemode = "none";
    mouse_events = [
      "click"
      "scroll"
    ];
    ratio = [
      2
      3
      5
    ];
    scrolloff = 5;
    show_hidden = false;
    show_symlink = true;
    sort_by = "alphabetical";
    sort_dir_first = true;
    sort_reverse = false;
    sort_sensitive = false;
    sort_translit = false;
    title_format = "Yazi: {cwd}";
  };
  open = {
    rules = [
      {
        name = "*/";
        use = [
          "edit"
          "open"
          "reveal"
        ];
      }
      {
        mime = "text/*";
        use = [
          "edit"
          "reveal"
        ];
      }
      {
        mime = "image/*";
        use = [
          "open"
          "reveal"
        ];
      }
      {
        mime = "{audio,video}/*";
        use = [
          "play"
          "reveal"
        ];
      }
      {
        mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}";
        use = [
          "extract"
          "reveal"
        ];
      }
      {
        mime = "application/{json,ndjson}";
        use = [
          "edit"
          "reveal"
        ];
      }
      {
        mime = "*/javascript";
        use = [
          "edit"
          "reveal"
        ];
      }
      {
        mime = "inode/empty";
        use = [
          "edit"
          "reveal"
        ];
      }
      {
        name = "*";
        use = [
          "open"
          "reveal"
        ];
      }
    ];
  };
  opener = {
    edit = [
      {
        block = true;
        desc = "$EDITOR";
        for = "unix";
        run = "\${EDITOR:-vi} \"$@\"";
      }
    ];
    extract = [
      {
        desc = "Extract here";
        for = "unix";
        run = "ya pub extract --list \"$@\"";
      }
    ];
    open = [
      {
        desc = "Open";
        for = "linux";
        run = "xdg-open \"$1\"";
      }
      {
        desc = "Open";
        for = "macos";
        run = "open \"$@\"";
      }
    ];
    play = [
      {
        for = "unix";
        orphan = true;
        run = "mpv --force-window \"$@\"";
      }
      {
        block = true;
        desc = "Show media info";
        for = "unix";
        run = "mediainfo \"$1\"; echo \"Press enter to exit\"; read _";
      }
    ];
    reveal = [
      {
        desc = "Reveal";
        for = "linux";
        run = "xdg-open \"$(dirname \"$1\")\"";
      }
      {
        desc = "Reveal";
        for = "macos";
        run = "open -R \"$1\"";
      }
      {
        block = true;
        desc = "Show EXIF";
        for = "unix";
        run = "exiftool \"$1\"; echo \"Press enter to exit\"; read _";
      }
    ];
  };
  preview = {
    cache_dir = "";
    image_delay = 30;
    image_filter = "triangle";
    image_quality = 75;
    max_height = 900;
    max_width = 600;
    sixel_fraction = 15;
    tab_size = 2;
    ueberzug_offset = [
      0
      0
      0
      0
    ];
    ueberzug_scale = 1;
    wrap = "no";
  };
  which = {
    sort_by = "none";
    sort_reverse = false;
    sort_sensitive = false;
    sort_translit = false;
  };
}
