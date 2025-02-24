{ appearance, ... }:
let
  n = appearance.palettes.nord;
  h = appearance.toHex;
  r = hex: alpha: appearance.toRgba hex alpha;
in
{
  programs.zathura = {
    enable = true;
    extraConfig = ''
      set adjust-open "best-fit"
      set pages-per-row 1
      set scroll-page-aware "true"
      set scroll-full-overlap 0.01
      set scroll-step 50
      set zoom-min 10
      set guioptions ""
      set font "${appearance.font.name} 16"
      set render-loading "false"
      set selection-clipboard clipboard
    ''
    + ''
      set default-fg                ${h n.nord6}
      set default-bg                ${h n.nord0}

      set completion-bg             ${h n.nord1}
      set completion-fg             ${h n.nord4}
      set completion-highlight-bg   ${h n.nord8}
      set completion-highlight-fg   ${h n.nord0}
      set completion-group-bg       ${h n.nord1}
      set completion-group-fg       ${h n.nord9}

      set statusbar-fg              ${h n.nord4}
      set statusbar-bg              ${h n.nord1}

      set notification-bg           ${h n.nord1}
      set notification-fg           ${h n.nord4}
      set notification-error-bg     ${h n.nord1}
      set notification-error-fg     ${h n.nord11}
      set notification-warning-bg   ${h n.nord1}
      set notification-warning-fg   ${h n.nord13}

      set inputbar-fg               ${h n.nord4}
      set inputbar-bg               ${h n.nord1}

      set recolor                   "true"
      set recolor-lightcolor        ${h n.nord0}
      set recolor-darkcolor         ${h n.nord6}

      set index-fg                  ${h n.nord4}
      set index-bg                  ${h n.nord0}
      set index-active-fg           ${h n.nord0}
      set index-active-bg           ${h n.nord8}

      set render-loading-bg         ${h n.nord0}
      set render-loading-fg         ${h n.nord4}

      set highlight-color           ${r n.nord15 "0.5"}
      set highlight-fg              ${r n.nord8 "0.5"}
      set highlight-active-color    ${r n.nord8 "0.5"}
    '';
  };
}
