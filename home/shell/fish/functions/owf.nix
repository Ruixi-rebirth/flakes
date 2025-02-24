''
  function owf
    set path (f)
    if test -n "$path"
      xdg-open $path
    end
  end
''
