{ appearance }:
let
  font = "${appearance.font.name} Medium 14";
in
''
  # Vertical Candidate List
  Vertical Candidate List=False
  # Use Per Screen DPI
  PerScreenDPI=True
  # Use mouse wheel to go to prev or next page
  WheelForPaging=True
  # Font
  Font="${font}"
  # Menu Font
  MenuFont="${font}"
  # Tray Font
  TrayFont="${font}"
  # Tray Label Outline Color
  TrayOutlineColor=#000000
  # Tray Label Text Color
  TrayTextColor=#ffffff
  # Prefer Text Icon
  PreferTextIcon=False
  # Show Layout Name In Icon
  ShowLayoutNameInIcon=True
  # Use input method language to display text
  UseInputMethodLangaugeToDisplayText=True
  # Theme
  Theme=Nord
  # Force font DPI on Wayland
  ForceWaylandDPI=0
''
