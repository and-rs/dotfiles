#include <rofi/mode-private.h>

#include <string>
#include <vector>

extern "C" {
unsigned int rofi_get_num_enabled_modes();
const Mode* rofi_get_mode(unsigned int index);
extern unsigned int curr_mode;
}

namespace {
guint pending = 0;
std::string stateFile;
std::vector<std::string> modeNames;

gboolean captureModes(gpointer) {
	pending = 0;
	for (unsigned int i = 0; i < rofi_get_num_enabled_modes(); ++i) {
		modeNames.emplace_back(mode_get_name(rofi_get_mode(i)));
	}
	return G_SOURCE_REMOVE;
}
}  // namespace

extern "C" {
// Rofi retains only modules exporting a Mode; this one adds no launcher tab.
G_MODULE_EXPORT Mode mode = {.abi_version = ABI_VERSION, .name = const_cast<char*>("tab-memory")};

G_MODULE_EXPORT const gchar* g_module_check_init(GModule*) {
	const char* path = g_getenv("ROFI_LAST_MODE_FILE");
	if (path != nullptr && path[0] != '\0') {
		stateFile = path;
		pending = g_idle_add(captureModes, nullptr);
	}
	return nullptr;
}

G_MODULE_EXPORT void g_module_unload(GModule*) {
	if (pending != 0) {
		g_source_remove(pending);
	}
	if (curr_mode < modeNames.size()) {
		const std::string& lastMode = modeNames[curr_mode];
		char* directory = g_path_get_dirname(stateFile.c_str());
		g_mkdir_with_parents(directory, 0700);
		g_free(directory);
		GError* error = nullptr;
		if (!g_file_set_contents(stateFile.c_str(), lastMode.c_str(), lastMode.size(), &error)) {
			g_warning("Could not remember Rofi tab: %s", error->message);
			g_error_free(error);
		}
	}
}
}
