/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Cassidy James Blaede <c@ssidyjam.es>
 */

public class Mercury.WebView : WebKit.WebView {
    private bool is_terminal = false;
    private HashTable<string, WebKit.Notification> pending_notifications =
        new HashTable<string, WebKit.Notification> (str_hash, str_equal);

    public WebView () {
        var user_content = new WebKit.UserContentManager ();
        user_content.add_style_sheet (
            new WebKit.UserStyleSheet (
                """
                mw-fi-feature-discovery-banner,
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

        notify["uri"].connect (() => {
            message ("uri changed: %s", uri);
        });

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

        permission_request.connect ((request) => {
            if (request is WebKit.NotificationPermissionRequest) {
                message ("notification permission requested");
                ((WebKit.NotificationPermissionRequest) request).allow ();
                return true;
            }
            return false;
        });

        show_notification.connect ((notification) => {
            message ("show_notification: title=%s body=%s tag=%s", notification.title, notification.body, notification.tag);

            string tag = notification.tag ?? "";
            pending_notifications[tag] = notification;

            var app_notification = new GLib.Notification (notification.title);
            app_notification.set_body (notification.body);
            // NOTE: WebKit doesn't expose the notification icon URL in its API
            app_notification.set_icon (new ThemedIcon (APP_ID));
            app_notification.set_default_action_and_target_value (
                "app.open-conversation",
                new Variant.string (tag)
            );
            Mercury.App.instance.send_notification (tag, app_notification);
            message ("send_notification called with tag=%s", tag);
            return true;
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

    public void notification_clicked (string tag) {
        message ("notification_clicked: tag=%s", tag);
        var notification = pending_notifications[tag];
        if (notification != null) {
            notification.clicked ();
            pending_notifications.remove (tag);
        } else {
            message ("notification_clicked: no pending notification for tag=%s", tag);
        }
    }
}
