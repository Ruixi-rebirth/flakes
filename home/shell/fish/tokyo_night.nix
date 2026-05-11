''
  # Tokyo Night Storm
  set -l fg      c0caf5
  set -l comment 565f89
  set -l cyan    7dcfff
  set -l blue    7aa2f7
  set -l purple  bb9af7
  set -l green   73daca
  set -l red     f7768e
  set -l yellow  e0af68
  set -l fg_dim  a9b1d6
  set -l sel_bg  292e42

  # Syntax Highlighting
  set -g fish_color_normal         $fg
  set -g fish_color_command        $cyan
  set -g fish_color_keyword        $purple
  set -g fish_color_quote          $green
  set -g fish_color_param          $fg_dim
  set -g fish_color_redirection    $blue
  set -g fish_color_end            $comment
  set -g fish_color_comment        $comment
  set -g fish_color_error          $red
  set -g fish_color_escape         $cyan
  set -g fish_color_operator       $purple
  set -g fish_color_autosuggestion $comment
  set -g fish_color_cancel         $red

  # Selection
  set -g fish_color_selection    --background=$sel_bg
  set -g fish_color_search_match --background=$sel_bg

  # Completion Pager
  set -g fish_pager_color_progress            $comment
  set -g fish_pager_color_prefix              $purple
  set -g fish_pager_color_completion          $fg
  set -g fish_pager_color_description         $comment
  set -g fish_pager_color_selected_background --background=$sel_bg
''
