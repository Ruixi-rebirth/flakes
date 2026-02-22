''
  function cd --wraps cd
    set -l _prev $PWD
    set -l _ret 0

    if test (count $argv) -gt 0
      if test "$argv[1]" = "-"
        if test -n "$_fish_my_oldpwd"
          builtin cd $_fish_my_oldpwd
          set _ret $status
          if test $_ret -eq 0
            pwd
          end
        else
          echo "No previous directory"
          return 1
        end
      else
        builtin cd $argv
        set _ret $status
      end
    else
      set -l git_root (git rev-parse --show-toplevel 2>/dev/null)
      if test -n "$git_root"
        builtin cd $git_root
        set _ret $status
      else
        builtin cd
        set _ret $status
      end
    end

    if test $_ret -eq 0
      set -g _fish_my_oldpwd $_prev
    end

    return $_ret
  end
''
