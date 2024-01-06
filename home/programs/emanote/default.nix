{
  # https://emanote.srid.ca/start/install/nix
  services.emanote = {
    enable = false;
    host = "127.0.0.1";
    port = 7000;
    notes = [
      "Blog"
    ];
  };
}
