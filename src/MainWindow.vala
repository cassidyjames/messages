/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Cassidy James Blaede <c@ssidyjam.es>
 */

[DBus (name = "org.freedesktop.portal.Background")]
interface BackgroundPortal : GLib.Object {
    [DBus (name = "RequestBackground")]
    public abstract GLib.ObjectPath request_background (
        string parent_window,
        GLib.HashTable<string, GLib.Variant> options
    ) throws GLib.DBusError, GLib.IOError;

    [DBus (name = "SetStatus")]
    public abstract void set_status (
        GLib.HashTable<string, GLib.Variant> options
    ) throws GLib.DBusError, GLib.IOError;
}

[GtkTemplate (ui = "/com/cassidyjames/messages/ui/main-window.ui")]
public class Mercury.MainWindow : Adw.ApplicationWindow {
    private const GLib.ActionEntry[] ACTION_ENTRIES = {
        { "reload", on_reload_activate },
    };

    [GtkChild] private unowned Gtk.Revealer header_revealer;
    [GtkChild] private unowned Gtk.ToggleButton autohide_button;
    [GtkChild] private unowned Gtk.Stack stack;
    [GtkChild] private unowned Adw.StatusPage loading_page;
    [GtkChild] private unowned Adw.StatusPage error_page;
    [GtkChild] private unowned Gtk.Button error_retry_button;

    private Mercury.WebView web_view;
    private string? last_failed_uri = null;
    private bool mouse_at_top = false;
    private uint hide_timeout_id = 0;
    private bool background_requested = false;

    public MainWindow (Adw.Application app) {
        Object (application: app);
        add_action_entries (ACTION_ENTRIES, this);
    }

    construct {
        maximized = App.settings.get_boolean ("window-maximized");
        fullscreened = App.settings.get_boolean ("window-fullscreened");

        App.settings.bind ("autohide-headerbar", autohide_button, "active", SettingsBindFlags.DEFAULT);
        App.settings.changed["autohide-headerbar"].connect (update_header_visibility);

        var motion = new Gtk.EventControllerMotion ();
        motion.motion.connect ((x, y) => {
            bool in_header_zone = y <= 8 ||
                (header_revealer.child_revealed && y <= header_revealer.get_height ());
            if (in_header_zone) {
                if (hide_timeout_id != 0) {
                    Source.remove (hide_timeout_id);
                    hide_timeout_id = 0;
                }
                if (!mouse_at_top) {
                    mouse_at_top = true;
                    update_header_visibility ();
                }
            } else if (mouse_at_top && hide_timeout_id == 0) {
                hide_timeout_id = Timeout.add (500, () => {
                    hide_timeout_id = 0;
                    mouse_at_top = false;
                    update_header_visibility ();
                    return Source.REMOVE;
                });
            }
        });
        ((Gtk.Widget) this).add_controller (motion);

        update_header_visibility ();
        add_css_class (PROFILE);

        icon_name = APP_ID;
        loading_page.icon_name = APP_ID;

        web_view = new Mercury.WebView ();
        web_view.load_uri ("https://messages.google.com/web");
        stack.add_named (web_view, "web");

        int window_width, window_height;
        App.settings.get ("window-size", "(ii)", out window_width, out window_height);
        set_default_size (window_width, window_height);

        error_retry_button.clicked.connect (() => {
            if (last_failed_uri != null) {
                web_view.load_uri (last_failed_uri);
            }
        });

        close_request.connect (() => {
            save_window_state ();
            hide ();
            return Gdk.EVENT_STOP;
        });

        map.connect (() => {
            if (!background_requested) {
                background_requested = true;
                request_background ();
            }
        });
        notify["fullscreened"].connect (save_window_state);
        notify["maximized"].connect (save_window_state);

        web_view.load_failed.connect ((load_event, failing_uri, error) => {
            last_failed_uri = failing_uri;
            error_page.description = error.message;
            stack.visible_child_name = "error";
            return true;
        });

        web_view.load_changed.connect (on_loading);
    }

    private void save_window_state () {
        if (fullscreened) {
            App.settings.set_boolean ("window-fullscreened", true);
        } else if (maximized) {
            App.settings.set_boolean ("window-maximized", true);
        } else {
            App.settings.set_boolean ("window-fullscreened", false);
            App.settings.set_boolean ("window-maximized", false);
            App.settings.set (
                "window-size", "(ii)",
                get_size (Gtk.Orientation.HORIZONTAL),
                get_size (Gtk.Orientation.VERTICAL)
            );
        }
    }

    private void on_loading (WebKit.LoadEvent load_event) {
        if (load_event == WebKit.LoadEvent.STARTED) {
            last_failed_uri = null;
            if (stack.visible_child_name == "error") {
                stack.visible_child_name = "loading";
            }
            return;
        }

        if (load_event != WebKit.LoadEvent.FINISHED) {
            return;
        }

        if (last_failed_uri != null) {
            return;
        }

        stack.visible_child_name = "web";
    }

    public void zoom_in () {
        web_view.zoom_level = double.min (web_view.zoom_level + 0.1, 5.0);
    }

    public void zoom_out () {
        web_view.zoom_level = double.max (web_view.zoom_level - 0.1, 0.25);
    }

    public void zoom_default () {
        web_view.zoom_level = 1.0;
    }

    private void update_header_visibility () {
        bool autohide = App.settings.get_boolean ("autohide-headerbar");
        header_revealer.reveal_child = !autohide || mouse_at_top;
    }

    public void toggle_fullscreen () {
        if (fullscreened) {
            unfullscreen ();
        } else {
            fullscreen ();
        }
    }

    public void notification_clicked (string tag) {
        web_view.notification_clicked (tag);
    }

    private void request_background () {
        var options = new HashTable<string, Variant> (str_hash, str_equal);
        options["reason"] = new Variant.string (
            _("Receive messages and deliver notifications")
        );
        options["autostart"] = new Variant.boolean (true);
        options["commandline"] = new Variant.strv ({ APP_ID, "--background" });

        Bus.get_proxy.begin<BackgroundPortal> (
            BusType.SESSION,
            "org.freedesktop.portal.Desktop",
            "/org/freedesktop/portal/desktop",
            DBusProxyFlags.NONE,
            null,
            (obj, res) => {
                try {
                    var portal = Bus.get_proxy.end<BackgroundPortal> (res);
                    portal.request_background ("", options);

                    var status_options = new HashTable<string, Variant> (str_hash, str_equal);
                    status_options["message"] = new Variant.string (_("Waiting for incoming messages"));
                    portal.set_status (status_options);
                } catch (Error e) {
                    warning ("Could not request background: %s", e.message);
                }
            }
        );
    }

    private void on_reload_activate () {
        web_view.reload ();
    }
}
