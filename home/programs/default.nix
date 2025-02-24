let
  directoryContents = builtins.readDir ./.;
  directories = builtins.filter (name: directoryContents.${name} == "directory") (
    builtins.attrNames directoryContents
  );
  modulePaths = map (name: ./. + "/${name}") directories;
in
{
  imports = modulePaths;
}
