//
//  Popopx.h
//  POPOPX
//
//  Created by Evgeny on 30/05/2022.
//  Copyright © 2022 SimpleX Chat. All rights reserved.
//
// Original work Copyright (C) 2020-2025 simplex.chat
// Modified by POPOPX Team in 2026 — see NOTICE for details

#ifndef Popopx_h
#define Popopx_h

#include <POPOPXSwitch/hs_init.h>
#include <POPOPXSwitch/objc.h>

extern void hs_init(int argc, char **argv[]);

typedef void* chat_ctrl;

// the last parameter is used to return the pointer to chat controller
extern char *chat_migrate_init_key(char *path, char *key, int keepKey, char *confirm, int backgroundMode, chat_ctrl *ctrl);
extern char *chat_close_store(chat_ctrl ctl);
extern char *chat_reopen_store(chat_ctrl ctl);
extern char *chat_send_cmd_retry(chat_ctrl ctl, char *cmd, int retryNum);
extern char *chat_recv_msg_wait(chat_ctrl ctl, int wait);
extern char *chat_parse_markdown(char *str);
extern char *chat_parse_server(char *str);
extern char *chat_parse_uri(char *str, int safe);
extern char *chat_password_hash(char *pwd, char *salt);
extern char *chat_valid_name(char *name);
// returns the canonical form of a badge code, or an empty string if it does not parse
extern char *chat_parse_badge_code(char *code);
extern int chat_json_length(char *str);
extern char *chat_encrypt_media(chat_ctrl ctl, char *key, char *frame, int len);
extern char *chat_decrypt_media(char *key, char *frame, int len);

// chat_write_file returns null-terminated string with JSON of WriteFileResult
extern char *chat_write_file(chat_ctrl ctl, char *path, char *data, int len);

// chat_read_file returns a buffer with:
// result status (1 byte), then if
//   status == 0 (success): buffer length (uint32, 4 bytes), buffer of specified length.
//   status == 1 (error): null-terminated error message string.
extern char *chat_read_file(char *path, char *key, char *nonce);

// chat_encrypt_file returns null-terminated string with JSON of WriteFileResult
extern char *chat_encrypt_file(chat_ctrl ctl, char *fromPath, char *toPath);

// chat_decrypt_file returns null-terminated string with the error message
extern char *chat_decrypt_file(char *fromPath, char *key, char *nonce, char *toPath);

// chat_resize_image_uri returns a data URI with the resized image
extern char *chat_resize_image_uri(char *data, int len, int maxSize);

// chat_resize_image returns base64-encoded resized image data
extern char *chat_resize_image(char *data, int len, int maxSize, int png);

// chat_resize_image_file_uri returns a data URI with the resized image from file path
extern char *chat_resize_image_file_uri(char *path, int maxSize);

// chat_resize_image_file returns base64-encoded resized image data from file path
extern char *chat_resize_image_file(char *path, int maxSize, int png);

// chat_resize_image_fd_uri returns a data URI with the resized image from file descriptor
extern char *chat_resize_image_fd_uri(int fd, int maxSize);

// chat_resize_image_fd returns base64-encoded resized image data from file descriptor
extern char *chat_resize_image_fd(int fd, int maxSize, int png);

#endif /* Popopx_h */
