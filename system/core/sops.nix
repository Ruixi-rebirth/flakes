{
  config,
  me,
  ...
}:
{
  # NOTE: https://github.com/Mic92/sops-nix#initrd-secrets
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    gnupg.sshKeyPaths = [ ];
    age = {
      sshKeyPaths = [ ];
      keyFile = "/var/lib/sops-nix/keys.txt"; # You must back up this keyFile yourself
      generateKey = true;
    };
    secrets = {
      Element_securityKey = {
        owner = "${me.userName}";
        path = "/home/" + "${me.userName}" + "/.config/element_SK/Element_securityKey";
      };
      OPENAI_API_KEY = {
        owner = "${me.userName}";
      };
      ANTHROPIC_API_KEY = {
        owner = "${me.userName}";
      };
      CACHIX_AUTH_TOKEN = {
        owner = "${me.userName}";
      };
      CACHIX_SIGNING_KEY = {
        owner = "${me.userName}";
      };
      GITHUB_TOKEN = {
        owner = "${me.userName}";
      };
    };
  };
  # issue: https://github.com/Mic92/sops-nix/issues/149
  # workaround:
  systemd.services.decrypt-sops = {
    description = "Decrypt sops secrets";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "2s";
    };
    script = config.system.activationScripts.setupSecrets.text;
  };
}
