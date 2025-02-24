''
  function xdg-get
    set filename (f)
    if test -n "$filename"
      set program (xdg-mime query default (xdg-mime query filetype $filename))
      echo "Open with $program"
    end
  end
''
