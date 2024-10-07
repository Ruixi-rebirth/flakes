{ pkgs, ... }:
let
  homepage = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/Ruixi-rebirth/someSource/main/firefox/homepage.html";
    sha256 = "sha256-UmT5B/dMl5UCM5O+pSFWxOl5HtDV2OqsM1yHSs/ciQ4=";
  };
  bg = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/Ruixi-rebirth/someSource/main/firefox/bg.png";
    sha256 = "sha256-dpMWCAtYT3ZHLftQQ32BIg800I7SDH6SQ9ET3yiOr90=";
  };
  logo = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/Ruixi-rebirth/someSource/main/firefox/logo.png";
    sha256 = "sha256-e6L3xq4AXv3V3LV7Os9ZE04R7U8vxdRornBP5x4DWm8=";
  };
in
{
  home = {
    sessionVariables = {
      BROWSER = "firefox";
      MOZ_ENABLE_WAYLAND = "1";
    };
  };
  programs.firefox = {
    enable = true;
    policies = {
      DisplayBookmarksToolbar = true;
      Preferences = {
        "browser.toolbars.bookmarks.visibility" = "never";
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "media.ffmpeg.vaapi.enabled" = true;
      };
    };
    profiles.default = {
      settings = {
        "browser.startup.homepage" = "file://${homepage}";
      };
      userChrome = ''
              /*================== SIDEBAR ==================*/
              /* The default sidebar width. */
              /* #sidebar-box { */
              /*   overflow: hidden!important; */
              /*   position: relative!important; */
              /*   transition: all 300ms!important; */
              /*   min-width: 60px !important; */
              /*   max-width: 60px !important; */
              /* } */

              /* The sidebar width when hovered. */
              /* #sidebar-box #sidebar,#sidebar-box:hover { */
              /*   transition: all 300ms!important; */
              /*   min-width: 60px !important; */
              /*   max-width: 200px !important; */
              /* } */


              /* only remove TST headers */
        #sidebar-box[sidebarcommand="treestyletab_piro_sakura_ne_jp-sidebar-action"] #sidebar-header {
                display: none; /* remove sidebar header */
                border-color: var(--base_color2) !important;
              }

              /*******************/
              .sidebar-splitter {
                /* display: none;  remove sidebar split line */
                min-width: 1px !important;
                max-width: 1px !important;
                border-color: var(--base_color2) !important;
              }

              /* remove top tabbar */ 
        #titlebar { visibility: collapse !important; }


              /*================== URL BAR ==================*/
        #urlbar .urlbar-input-box {
                text-align: center !important;
              }


              * {
              font-family: JetBrainsMono Nerd Font Mono !important;
              font-size: 12pt !important;
              }

              /* #nav-bar { visibility: collapse !important; } */
                /* hide horizontal tabs at the top of the window */
                #TabsToolbar > * {
                  visibility: collapse;
                }

                /* hide navigation bar when it is not focused; use Ctrl+L to get focus */
                #main-window:not([customizing]) #navigator-toolbox:not(:focus-within):not(:hover) {
                  margin-top: -45px;
                }
                #navigator-toolbox {
                  transition: 0.2s margin-top ease-out;
                }
      '';
      userContent = ''
                /*hide all scroll bars*/
                /* *{ scrollbar-width: none !important } */


                * {
                font-family: JetBrainsMono Nerd Font Mono;
                }

                @-moz-document url-prefix("about:") {
                    :root {
                        --in-content-page-background: #1E1E2E !important;
                    }
                }
        
        
                @-moz-document url-prefix(about:home), url-prefix(about:newtab){

            /* show nightly logo instead of default firefox logo in newtabpage */
            .search-wrapper .logo-and-wordmark .logo {
                background: url("${logo}") no-repeat center !important;
                background-size: auto !important;
                background-size: 82px !important;
                display: inline-block !important;
                height: 82px !important;
                width: 82px !important;
            }

            body {
                background-color: #000000 !important;
                background: url("${bg}") no-repeat fixed !important;
                background-size: cover !important;
                --newtab-background-color: #000000 !important;
                --newtab-background-color-secondary: #101010 !important;
            }

            body[lwt-newtab-brighttext] {
                --newtab-background-color: #000000 !important;
                --newtab-background-color-secondary: #101010 !important;

            }

            .top-site-outer .top-site-icon {
                background-color: transparent !important;

            }

            .top-site-outer .tile {
                background-color: rgba(49, 49, 49, 0.4) !important;
            }

            .top-sites-list:not(.dnd-active) .top-site-outer:is(.active, :focus, :hover) {
                background: rgba(49, 49, 49, 0.3) !important;
            }

            .top-site-outer .context-menu-button:is(:active, :focus) {
                background-color: transparent !important;
            }

            .search-wrapper .search-handoff-button{
                border-radius: 40px !important;
                background-color: rgba(49, 49, 49, 0.4) !important;
            }
        }
      '';
    };
  };

}
