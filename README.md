# Mercury for Google Messages

Google Messages, on your desktop. Mercury delivers your messages to you on your Linux desktop via the Google Messages web app. Rather than keeping a tab open all the time, let Mercury keep you connected with notifications and quick access to your messages.

## Features

- Native notifications
- Runs in the background
- Light/dark style support
- Minimal UI with optionally auto-hiding titlebar
- Keyboard shortcuts for zoom, closing, and fullscreen

## Known limitations

- Notifications require toggling the webapp's notification setting off and back on EVERY SESSION. This is super annoying!

- Notifications use the app icon instead of the sender/conversation avatar. Unfortunately WebKit does not expose the icon URL from web notifications.

- WebKit sends an MPRIS notification for some reason; something to do with the Google Messages service worker registering a media session so that it can play notification sounds? No idea, but I'd like to get rid of it.

## Building

Mercury is built for GNOME using Flatpak and GNOME Builder. Open this project in GNOME Builder for development, or build it using the Flatpak manifest.
