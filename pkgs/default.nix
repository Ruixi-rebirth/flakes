{
  overlay =
    final: prev:
    let
      dirContents = builtins.readDir ../pkgs;
      genPackage = name: {
        inherit name;
        value = final.callPackage (../pkgs + "/${name}") { };
      };
      names = builtins.filter (name: dirContents.${name} == "directory") (builtins.attrNames dirContents);
    in
    builtins.listToAttrs (map genPackage names);
}
