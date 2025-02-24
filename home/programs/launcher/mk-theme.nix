{ appearance }:
let
  n = appearance.palettes.nord;
  h = appearance.toHex;
in
{
  mkRofiTheme =
    {
      windowWidth ? "24%",
      lines ? 6,
      placeholder ? "Search",
      showIcons ? false,
      extraConfiguration ? "",
      extraListview ? "",
      extraWidgets ? "",
    }:
    ''
      configuration {
        font:            "${appearance.font.name} 13";
        show-icons:      ${if showIcons then "true" else "false"};
        disable-history: false;
        sidebar-mode:    false;
        ${extraConfiguration}
      }

      * {
        bg: ${h n.nord0};
        fg: ${h n.nord6};
        ac: ${h n.nord9};
        al: ${h n.nord1};
        se: ${h n.nord2};
      }

      window {
        transparency:     "real";
        background-color: @al;
        text-color:       @fg;
        border:           0px;
        border-radius:    4px;
        width:            ${windowWidth};
        location:         center;
      }

      inputbar {
        children:         [ prompt, entry ];
        background-color: @bg;
        text-color:       @fg;
        expand:           false;
        border:           0px;
        border-radius:    6px;
        margin:           12px 12px 6px 12px;
        padding:          10px 14px;
      }

      prompt {
        enabled:          true;
        background-color: inherit;
        text-color:       @ac;
        font:             "${appearance.font.name} 13";
        vertical-align:   0.5;
        padding:          0px 8px 0px 0px;
      }

      entry {
        background-color:  inherit;
        text-color:        @fg;
        placeholder-color: @se;
        expand:            true;
        horizontal-align:  0;
        vertical-align:    0.5;
        placeholder:       "${placeholder}";
        blink:             true;
        font:              "${appearance.font.name} 13";
      }

      listview {
        background-color: @al;
        padding:          6px 10px 10px 10px;
        columns:          1;
        lines:            ${toString lines};
        spacing:          2px;
        cycle:            false;
        dynamic:          true;
        layout:           vertical;
        ${extraListview}
      }

      mainbox {
        background-color: @al;
        border:           0px;
        children:         [ inputbar, listview ];
        spacing:          0px;
        padding:          0px;
      }

      element {
        background-color: @al;
        text-color:       ${h n.nord4};
        orientation:      horizontal;
        border-radius:    4px;
        padding:          8px 10px;
      }

      element-text {
        background-color: inherit;
        text-color:       inherit;
        expand:           true;
        horizontal-align: 0;
        vertical-align:   0.5;
        margin:           ${if showIcons then "0px 0px 0px 8px" else "0px 4px"};
      }

      element selected {
        background-color: @se;
        text-color:       @fg;
        border-radius:    4px;
      }

      ${
        if showIcons then
          ''
            element-icon {
              background-color: inherit;
              text-color:       inherit;
              horizontal-align: 0.5;
              vertical-align:   0.5;
              size:             26px;
              border:           0px;
            }
          ''
        else
          ""
      }

      ${extraWidgets}
    '';
}
