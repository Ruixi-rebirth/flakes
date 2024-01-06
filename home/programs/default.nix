let
  directoryContents = builtins.readDir ./.;
  directories = builtins.filter
    (name: directoryContents."${name}" == "directory" && name != "waybar")
    (builtins.attrNames directoryContents);
  imports = map (name: ./. + "/${name}") directories;
in
{
  imports = imports;
}
