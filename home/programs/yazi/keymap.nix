{
  manager = {
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
        run = "shell --cursor=7 --interactive --orphan yt-dlp -ic";
      }
      {
        on = [
          "y"
          "d"
          "a"
        ];
        run = "shell --cursor=7 --interactive --orphan yt-dlp -x --audio-format mp3";
      }
    ];
  };
}
