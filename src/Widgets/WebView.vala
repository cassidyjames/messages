/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Cassidy James Blaede <c@ssidyjam.es>
 */

public class Mercury.WebView : WebKit.WebView {
    private bool is_terminal = false;

    public WebView () {
        var user_content = new WebKit.UserContentManager ();
        user_content.add_style_sheet (
            new WebKit.UserStyleSheet (
                """
                .call-nav-list,
                .call-nav-list + hr {
                    display: none !important;
                }
                """,
                WebKit.UserContentInjectedFrames.ALL_FRAMES,
                WebKit.UserStyleLevel.USER,
                null, null
            )
        );

        Object (
            hexpand: true,
            vexpand: true,
            network_session: new WebKit.NetworkSession (null, null),
            user_content_manager: user_content
        );
    }

    construct {
        is_terminal = Posix.isatty (Posix.STDIN_FILENO);

        var webkit_settings = new WebKit.Settings () {
            default_font_family = Gtk.Settings.get_default ().gtk_font_name,
            enable_back_forward_navigation_gestures = false,
            enable_developer_extras = is_terminal,
            enable_html5_database = true,
            enable_html5_local_storage = true,
            enable_smooth_scrolling = true,
            enable_webgl = true,
        };

        settings = webkit_settings;

        var cookie_manager = network_session.get_cookie_manager ();
        cookie_manager.set_accept_policy (WebKit.CookieAcceptPolicy.ALWAYS);

        string config_dir = Path.build_path (
            Path.DIR_SEPARATOR_S,
            Environment.get_user_config_dir (),
            Environment.get_prgname ()
        );

        DirUtils.create_with_parents (config_dir, 0700);

        string cookies = Path.build_filename (config_dir, "cookies");
        cookie_manager.set_persistent_storage (
            cookies,
            WebKit.CookiePersistentStorage.SQLITE
        );

        context_menu.connect ((menu, hit_test_result) => {
            if (!hit_test_result.context_is_link () && !is_terminal) {
                return true;
            }
            menu.remove_all ();
            if (hit_test_result.context_is_link ()) {
                menu.append (new WebKit.ContextMenuItem.from_stock_action (
                    WebKit.ContextMenuAction.COPY_LINK_TO_CLIPBOARD
                ));
            }
            if (is_terminal) {
                menu.append (new WebKit.ContextMenuItem.from_stock_action (
                    WebKit.ContextMenuAction.INSPECT_ELEMENT
                ));
            }
            return false;
        });

        decide_policy.connect ((decision, type) => {
            if (type == WebKit.PolicyDecisionType.NEW_WINDOW_ACTION) {
                new Gtk.UriLauncher (
                    ((WebKit.NavigationPolicyDecision)decision).
                    navigation_action.get_request ().get_uri ()
                ).launch.begin (null, null);
            }
            return false;
        });

        // Intercept pinch-to-zoom
        var pinch_gesture = new Gtk.GestureZoom () {
            propagation_phase = Gtk.PropagationPhase.CAPTURE
        };
        pinch_gesture.begin.connect ((sequence) => {
            pinch_gesture.set_state (Gtk.EventSequenceState.CLAIMED);
        });
        add_controller (pinch_gesture);

        var back_click_gesture = new Gtk.GestureClick () {
            button = 8
        };
        back_click_gesture.pressed.connect (go_back);
        add_controller (back_click_gesture);

        var forward_click_gesture = new Gtk.GestureClick () {
            button = 9
        };
        forward_click_gesture.pressed.connect (go_forward);
        add_controller (forward_click_gesture);
    }
}
