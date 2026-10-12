#include <stdlib.h>
#include <string.h>

// Stub for chat_parse_badge_code until Haskell lib is rebuilt.
// Returns heap-allocated empty string so fromCString() can safely free() it.
char *chat_parse_badge_code(char *code) {
    return strdup("");
}
