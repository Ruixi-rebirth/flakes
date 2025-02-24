{ appearance }:
let
  n = appearance.palettes.nord;
in
''
  # Nord
  set -g fish_color_normal         ${n.nord4}
  set -g fish_color_command        ${n.nord8}
  set -g fish_color_keyword        ${n.nord9}
  set -g fish_color_quote          ${n.nord14}
  set -g fish_color_param          ${n.nord4}
  set -g fish_color_redirection    ${n.nord9}
  set -g fish_color_end            ${n.nord3}
  set -g fish_color_comment        ${n.nord3}
  set -g fish_color_error          ${n.nord11}
  set -g fish_color_escape         ${n.nord8}
  set -g fish_color_operator       ${n.nord9}
  set -g fish_color_autosuggestion ${n.nord3}
  set -g fish_color_cancel         ${n.nord11}

  # Selection
  set -g fish_color_selection    --background=${n.nord2}
  set -g fish_color_search_match --background=${n.nord2}

  # Completion Pager
  set -g fish_pager_color_progress            ${n.nord3}
  set -g fish_pager_color_prefix              ${n.nord9}
  set -g fish_pager_color_completion          ${n.nord4}
  set -g fish_pager_color_description         ${n.nord3}
  set -g fish_pager_color_selected_background --background=${n.nord2}
''
