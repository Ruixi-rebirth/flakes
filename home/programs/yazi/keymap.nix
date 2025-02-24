{
  mgr = {
    prepend_keymap = [
      {
        on = [
          "g"
          "f"
        ];
        run = "cd ~/Flakes";
      }
      {
        on = [
          "y"
          "d"
          "v"
        ];
        run = "shell --interactive --orphan 'yt-dlp -ic '";
      }
      {
        on = [
          "y"
          "y"
        ];
        run = "yank";
        desc = "Yank selected files (copy)";
      }
      {
        on = [
          "y"
          "d"
          "a"
        ];
        run = "shell --interactive --orphan 'yt-dlp -x --audio-format mp3 '";
      }
    ];
  };
}
