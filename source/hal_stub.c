#include "hal.h"

void hal_print(const char *str) {
	printf("%s\n", str);
}

void stub(const char *name) {
	printf("%s is a stub\n", name);
}

void hal_loop()                                         { stub("hal_loop"); }
void hal_graphics(const struct variable *shape)         { stub("hal_graphics"); }
void hal_image()                                        { stub("hal_image"); }
void hal_sound()                                        { stub("hal_sound"); }
void hal_synth(const uint8_t *bytes, uint32_t length)   { stub("hal_synth"); }
void hal_audioloop()                                    { stub("hal_audioloop"); }

void *hal_window(struct context *context,
                 struct variable *uictx,
                 int32_t *w, int32_t *h,
                 struct variable *logic)                { stub("hal_window"); return NULL; }
void *hal_label (int32_t x, int32_t y,
                 int32_t *w, int32_t *h,
                 const char *str)                       { stub("hal_label"); return NULL; }
void *hal_input (struct variable *uictx,
                 int32_t x, int32_t y,
                 int32_t *w, int32_t *h,
                 struct variable *hint,
                 bool multiline)                        { stub("hal_input"); return NULL; }
void *hal_button(struct context *context,
                 struct variable *uictx,
                 int32_t x, int32_t y,
                 int32_t *w, int32_t *h,
                 struct variable *logic,
                 const char *str, const char *img)      { stub("hal_button"); return NULL; }
void *hal_table (struct context *context,
                 struct variable *uictx,
                 int x, int y, int w, int h,
                 struct variable *list,
                 struct variable *logic)                { stub("hal_table"); return NULL; }

void hal_sound_url(const char *address)                 { stub("hal_sound_url"); }
void hal_sound_bytes(const uint8_t *bytes,
                     uint32_t length)                   { stub("hal_sound_bytes"); }

void hal_save(struct context *context,
              const struct byte_array *key,
              const struct variable *value)             { stub("hal_save"); }
struct variable *hal_load(struct context *context,
                          const struct byte_array *key) { stub("hal_load"); return NULL; }

void hal_file_listen(struct context *context,
                     const char *path,
                     struct variable *listener)         { stub("hal_file_listen"); }

struct variable *hal_ui_get(struct context *context,
                            void *field)                { stub("hal_ui_get"); return NULL; }
void hal_ui_set(void *field, struct variable *value)    { stub("hal_ui_set"); }