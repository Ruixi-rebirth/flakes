{ appearance }:
let
  n = appearance.palettes.nord;
  h = appearance.toHex;
in
''
  # vim: ft=dosini
  [Metadata]
  Name=Nord-Light
  Version=0.1
  Author=MiraculousMoon
  Description=Nord Color Theme (Light)
  ScaleWithDPI=True

  [InputPanel]
  # 字体
  Font=Sans 13
  # 非选中候选字颜色
  NormalColor=${h n.nord9}
  # 选中候选字颜色
  HighlightCandidateColor=${h n.nord10}
  # 高亮前景颜色(输入字符颜色)
  HighlightColor=${h n.nord10}
  # 输入字符背景颜色
  HighlightBackgroundColor=${h n.nord6}
  #
  Spacing=3

  [InputPanel/TextMargin]
  # 候选字对左边距
  Left=10
  # 候选字对右边距
  Right=10
  # 候选字向上边距
  Top=6
  # 候选字向下边距
  Bottom=6

  [InputPanel/Background]
  Color=${h n.nord5}

  [InputPanel/Background/Margin]
  Left=2
  Right=2
  Top=2
  Bottom=2

  [InputPanel/Highlight]
  Color=${h n.nord4}

  [InputPanel/Highlight/Margin]
  # 高亮区域左边距
  Left=10
  # 高亮区域右边距
  Right=10
  # 高亮区域上边距
  Top=7
  # 高亮区域下边距
  Bottom=7

  [Menu]
  Font=Sans 10
  NormalColor=${h n.nord0}
  #HighlightColor=${h n.nord3}
  Spacing=3

  [Menu/Background]
  Color=${h n.nord4}

  [Menu/Background/Margin]
  Left=2
  Right=2
  Top=2
  Bottom=2

  [Menu/ContentMargin]
  Left=2
  Right=2
  Top=2
  Bottom=2

  [Menu/Highlight]
  Color=${h n.nord3}

  [Menu/Highlight/Margin]
  Left=10
  Right=10
  Top=5
  Bottom=5

  [Menu/Separator]
  Color=${h n.nord0}

  [Menu/CheckBox]
  Image="${./radio.png}"

  [Menu/SubMenu]
  Image="${./arrow.png}"

  [Menu/TextMargin]
  Left=5
  Right=5
  Top=5
  Bottom=5
''
