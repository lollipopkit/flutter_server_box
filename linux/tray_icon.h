#ifndef RUNNER_TRAY_ICON_H_
#define RUNNER_TRAY_ICON_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

G_BEGIN_DECLS

// The panel status icon, and the rows in its menu.
//
// Hand-written like the other two, but it can do less, and the limit is not
// this app's. A panel icon here is a `libayatana-appindicator`, whose menu is
// serialised to the panel over the dbusmenu protocol — a widget cannot cross
// D-Bus. What can is a label and an image per item, so a row is one line of
// text with the chart beside it as a small picture, and the two-line layout
// macOS and Windows draw is simply not available.
//
// The image is drawn here with Cairo, from the series Dart already scaled to
// 0…1. Nothing here knows what a percentage is.
//
// `window` is what a click brings forward, and the messenger is what carries
// the payload in and the clicks back out.
void tray_icon_init(GtkWindow* window, FlBinaryMessenger* messenger);

// Takes the icon out of the panel. Called when the window goes.
void tray_icon_dispose();

G_END_DECLS

#endif  // RUNNER_TRAY_ICON_H_
