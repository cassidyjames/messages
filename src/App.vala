/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024–2026 Cassidy James Blaede <c@ssidyjam.es>
 */

public class Mercury.App : Adw.Application {
    public static GLib.Settings settings;

    private MainWindow? app_window = null;
    private bool background_start = false;

    public App () {
        Object (application_id: APP_ID);
        _instance = this;
        add_main_option (
            "background", 0, OptionFlags.NONE, OptionArg.NONE,
            "Start in the background without opening a window", null
        );
    }

    public static App _instance = null;
    public static App instance {
        get {
            if (_instance == null) {
                _instance = new App ();
            }
            return _instance;
        }
    }

    static construct {
        settings = new Settings (APP_ID);
    }

    protected override int handle_local_options (VariantDict options) {
        if (options.contains ("background")) {
            background_start = true;
        }
        return -1;
    }

    protected override void activate () {
        if (app_window == null) {
            app_window = new MainWindow (this);

            var quit_action = new SimpleAction ("quit", null);
            var toggle_fullscreen_action = new SimpleAction ("toggle_fullscreen", null);
            var zoom_in_action = new SimpleAction ("zoom-in", null);
            var zoom_out_action = new SimpleAction ("zoom-out", null);
            var zoom_default_action = new SimpleAction ("zoom-default", null);
            var open_conversation_action = new SimpleAction ("open-conversation", VariantType.STRING);

            add_action (quit_action);
            add_action (toggle_fullscreen_action);
            add_action (zoom_in_action);
            add_action (zoom_out_action);
            add_action (zoom_default_action);
            add_action (open_conversation_action);

            set_accels_for_action ("app.quit", {"<Ctrl>Q", "<Ctrl>W"});
            set_accels_for_action ("app.toggle_fullscreen", {"F11"});
            set_accels_for_action ("app.zoom-in", {"<Ctrl>plus", "<Ctrl>equal"});
            set_accels_for_action ("app.zoom-out", {"<Ctrl>minus"});
            set_accels_for_action ("app.zoom-default", {"<Ctrl>0"});

            quit_action.activate.connect (() => quit ());
            toggle_fullscreen_action.activate.connect (app_window.toggle_fullscreen);
            zoom_in_action.activate.connect (app_window.zoom_in);
            zoom_out_action.activate.connect (app_window.zoom_out);
            zoom_default_action.activate.connect (app_window.zoom_default);
            open_conversation_action.activate.connect ((parameter) => {
                app_window.present ();
                if (parameter != null) {
                    string tag = parameter.get_string ();
                    if (tag != "") {
                        app_window.notification_clicked (tag);
                    }
                }
            });
        }

        if (!background_start) {
            app_window.present ();
        }
        background_start = false;
    }

    public static int main (string[] args) {
        var app = new App ();
        return app.run (args);
    }
}
