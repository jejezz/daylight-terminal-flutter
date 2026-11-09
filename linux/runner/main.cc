#include "my_application.h"

#include <stdlib.h>
#include <string.h>
#include <strings.h>

int main(int argc, char** argv) {
  // Impeller is off by default (startup is ~3x slower with it). Set
  // DAYLIGHT_IMPELLER=1/true/on/yes to enable. The engine reads switches from
  // FLUTTER_ENGINE_SWITCHES, so set it before the engine is created.
  const char* v = getenv("DAYLIGHT_IMPELLER");
  bool impeller = v != nullptr && (strcmp(v, "1") == 0 ||
                                   strcasecmp(v, "true") == 0 ||
                                   strcasecmp(v, "on") == 0 ||
                                   strcasecmp(v, "yes") == 0);
  setenv("FLUTTER_ENGINE_SWITCHES", "1", 1);
  setenv("FLUTTER_ENGINE_SWITCH_1",
         impeller ? "enable-impeller=true" : "enable-impeller=false", 1);

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
