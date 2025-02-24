{ config, ... }:
{
  services = {
    ollama = {
      enable = true;
      port = 1111;
      environmentVariables = {
        # HIP_VISIBLE_DEVICES = "0,1";
        # OLLAMA_LLM_LIBRARY = "cpu";
      };
      home = "/var/lib/ollama";
      loadModels = [
        "deepseek-r1:8b"
      ];
      openFirewall = true;
      acceleration = "cuda";
    };
    nextjs-ollama-llm-ui = {
      enable = config.services.ollama.enable;
      port = 3000;
      ollamaUrl = "http://127.0.0.1:1111";
    };
  };
}
