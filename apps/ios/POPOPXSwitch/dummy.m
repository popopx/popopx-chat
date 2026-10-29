//
//  dummy.m
//  POPOPXChat
//
//  Created by Evgeny on 30/05/2022.
//  Copyright © 2022 SimpleX Chat. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <string.h>

// Forward declaration of the actual Haskell FFI function
typedef void* chat_ctrl;
extern char *chat_migrate_init_key(char *path, char *key, int keepKey, char *confirm, int backgroundMode, chat_ctrl *ctrl);

#if defined(__x86_64__) && TARGET_IPHONE_SIMULATOR

#import <dirent.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

int readdir_r$INODE64(DIR *restrict dirp, struct dirent *restrict entry,
                      struct dirent **restrict result) {
    return readdir_r(dirp, entry, result);
}

DIR *opendir$INODE64(const char *name) {
    return opendir(name);
}

int readdir$INODE64(DIR *restrict dirp, struct dirent *restrict entry,
                      struct dirent **restrict result) {
    return readdir_r(dirp, entry, result);
}

DIR *fdopendir$INODE64(const char *name) {
    return opendir(name);
}

#pragma clang diagnostic pop

#endif
