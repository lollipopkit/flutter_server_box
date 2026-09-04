#include "tray_icon.h"

#include <libayatana-appindicator/app-indicator.h>

#include <cmath>
#include <string>
#include <vector>

namespace {

AppIndicator* g_indicator = nullptr;
GtkWidget* g_menu = nullptr;
GtkWindow* g_window = nullptr;
FlMethodChannel* g_channel = nullptr;

// Where the chart is drawn, in pixels. A dbusmenu item's image is whatever it
// is given, and a panel scales it to its own row height — so this is a shape
// rather than a size.
constexpr int kChartWidth = 60;
constexpr int kChartHeight = 18;

// What a row carries back when it is clicked. Freed with the menu item.
struct RowId {
  std::string id;
};

void SendMethod(const char* method, FlValue* args) {
  if (g_channel == nullptr) return;
  g_autoptr(FlValue) owned = args == nullptr ? fl_value_new_null() : args;
  fl_method_channel_invoke_method(g_channel, method, owned, nullptr, nullptr,
                                  nullptr);
}

void OnCommand(GtkMenuItem*, gpointer data) {
  SendMethod(static_cast<const char*>(data), nullptr);
}

void OnRow(GtkMenuItem*, gpointer data) {
  const auto* row = static_cast<RowId*>(data);
  SendMethod("server", fl_value_new_string(row->id.c_str()));
}

void FreeRow(gpointer data, GClosure*) { delete static_cast<RowId*>(data); }

const char* LookupString(FlValue* map, const char* key) {
  FlValue* value = fl_value_lookup_string(map, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_STRING) {
    return "";
  }
  return fl_value_get_string(value);
}

/// The series as a small picture, because that is the only way a chart reaches
/// a dbusmenu row.
///
/// Drawn on transparency and left uncoloured beyond a single stroke: the panel
/// theme is not knowable from here, and a filled shape in the wrong colour is
/// worse than a thin line in a neutral one.
GdkPixbuf* DrawChart(const std::vector<double>& samples) {
  if (samples.size() < 2) return nullptr;

  cairo_surface_t* surface = cairo_image_surface_create(
      CAIRO_FORMAT_ARGB32, kChartWidth, kChartHeight);
  cairo_t* cr = cairo_create(surface);
  cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
  cairo_set_source_rgba(cr, 0, 0, 0, 0);
  cairo_paint(cr);
  cairo_set_operator(cr, CAIRO_OPERATOR_OVER);

  const double step =
      static_cast<double>(kChartWidth - 2) / (samples.size() - 1);
  cairo_set_line_width(cr, 1.2);
  cairo_set_source_rgba(cr, 0.42, 0.55, 0.86, 0.95);
  for (size_t i = 0; i < samples.size(); i++) {
    const double value = std::fmin(std::fmax(samples[i], 0.0), 1.0);
    const double x = 1 + step * i;
    const double y = (kChartHeight - 2) * (1.0 - value) + 1;
    if (i == 0) {
      cairo_move_to(cr, x, y);
    } else {
      cairo_line_to(cr, x, y);
    }
  }
  cairo_stroke(cr);
  cairo_destroy(cr);

  GdkPixbuf* pixbuf =
      gdk_pixbuf_get_from_surface(surface, 0, 0, kChartWidth, kChartHeight);
  cairo_surface_destroy(surface);
  return pixbuf;
}

GtkWidget* MakeCommand(const char* label, const char* method) {
  GtkWidget* item = gtk_menu_item_new_with_label(label);
  g_signal_connect(item, "activate", G_CALLBACK(OnCommand),
                   const_cast<char*>(method));
  return item;
}

GtkWidget* MakeRow(FlValue* line) {
  // The one-line label the model already formats for exactly this — see
  // `TrayLine.label`.
  GtkWidget* item = gtk_menu_item_new();
  GtkWidget* box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
  GtkWidget* label = gtk_label_new(LookupString(line, "label"));
  gtk_label_set_xalign(GTK_LABEL(label), 0.0);
  gtk_box_pack_start(GTK_BOX(box), label, TRUE, TRUE, 0);

  std::vector<double> samples;
  FlValue* chart = fl_value_lookup_string(line, "chart");
  if (chart != nullptr && fl_value_get_type(chart) == FL_VALUE_TYPE_LIST) {
    for (size_t i = 0; i < fl_value_get_length(chart); i++) {
      FlValue* sample = fl_value_get_list_value(chart, i);
      if (fl_value_get_type(sample) == FL_VALUE_TYPE_FLOAT) {
        samples.push_back(fl_value_get_float(sample));
      }
    }
  }
  if (GdkPixbuf* pixbuf = DrawChart(samples)) {
    GtkWidget* image = gtk_image_new_from_pixbuf(pixbuf);
    g_object_unref(pixbuf);
    gtk_box_pack_end(GTK_BOX(box), image, FALSE, FALSE, 0);
  }

  gtk_container_add(GTK_CONTAINER(item), box);

  auto* row = new RowId{LookupString(line, "id")};
  g_signal_connect_data(item, "activate", G_CALLBACK(OnRow), row, FreeRow,
                        static_cast<GConnectFlags>(0));
  return item;
}

void Update(FlValue* payload) {
  if (g_indicator == nullptr) {
    // The application icon already ships as a Flutter asset. Point the
    // indicator at that directory instead of keeping a second tray-only copy.
    g_autofree gchar* dir = g_path_get_dirname(
        g_file_read_link("/proc/self/exe", nullptr) ?: g_strdup("."));
    g_autofree gchar* icon_dir =
        g_build_filename(dir, "data", "flutter_assets", "assets", nullptr);
    g_indicator = app_indicator_new_with_path(
        "serverbox", "app_icon", APP_INDICATOR_CATEGORY_APPLICATION_STATUS,
        icon_dir);
    app_indicator_set_status(g_indicator, APP_INDICATOR_STATUS_ACTIVE);
    app_indicator_set_title(g_indicator, "ServerBox");
  }

  // Rebuilt whole: dbusmenu has no notion of editing one item, and the Dart
  // side already withholds a push that would change nothing.
  if (g_menu != nullptr) gtk_widget_destroy(g_menu);
  g_menu = gtk_menu_new();

  gtk_menu_shell_append(GTK_MENU_SHELL(g_menu),
                        MakeCommand("Open ServerBox", "open"));
  gtk_menu_shell_append(GTK_MENU_SHELL(g_menu), gtk_separator_menu_item_new());

  GtkWidget* header = gtk_menu_item_new_with_label("Servers");
  gtk_widget_set_sensitive(header, FALSE);
  gtk_menu_shell_append(GTK_MENU_SHELL(g_menu), header);

  FlValue* lines = fl_value_lookup_string(payload, "lines");
  const size_t count =
      lines != nullptr && fl_value_get_type(lines) == FL_VALUE_TYPE_LIST
          ? fl_value_get_length(lines)
          : 0;
  if (count == 0) {
    GtkWidget* empty = gtk_menu_item_new_with_label("Empty");
    gtk_widget_set_sensitive(empty, FALSE);
    gtk_menu_shell_append(GTK_MENU_SHELL(g_menu), empty);
  } else {
    for (size_t i = 0; i < count; i++) {
      gtk_menu_shell_append(GTK_MENU_SHELL(g_menu),
                            MakeRow(fl_value_get_list_value(lines, i)));
    }
  }

  gtk_menu_shell_append(GTK_MENU_SHELL(g_menu), gtk_separator_menu_item_new());
  gtk_menu_shell_append(GTK_MENU_SHELL(g_menu),
                        MakeCommand("Settings", "settings"));
  gtk_menu_shell_append(GTK_MENU_SHELL(g_menu), MakeCommand("Quit", "quit"));

  gtk_widget_show_all(g_menu);
  app_indicator_set_menu(g_indicator, GTK_MENU(g_menu));
}

void OnMethodCall(FlMethodChannel*, FlMethodCall* call, gpointer) {
  const gchar* method = fl_method_call_get_name(call);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (g_strcmp0(method, "update") == 0) {
    FlValue* args = fl_method_call_get_args(call);
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      Update(args);
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "destroy") == 0) {
    tray_icon_dispose();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(call, response, nullptr);
}

}  // namespace

void tray_icon_init(GtkWindow* window, FlBinaryMessenger* messenger) {
  g_window = window;
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_channel = fl_method_channel_new(messenger, "tech.lolli.toolbox/tray",
                                    FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(g_channel, OnMethodCall, nullptr,
                                            nullptr);
}

void tray_icon_dispose() {
  if (g_menu != nullptr) {
    gtk_widget_destroy(g_menu);
    g_menu = nullptr;
  }
  if (g_indicator != nullptr) {
    app_indicator_set_status(g_indicator, APP_INDICATOR_STATUS_PASSIVE);
    g_object_unref(g_indicator);
    g_indicator = nullptr;
  }
  if (g_channel != nullptr) {
    g_object_unref(g_channel);
    g_channel = nullptr;
  }
  g_window = nullptr;
}
