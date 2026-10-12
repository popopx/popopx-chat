#ifndef CACTUS_ENGINE_H
#define CACTUS_ENGINE_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void* cactus_model_t;
typedef void* cactus_index_t;
typedef void* cactus_stream_transcribe_t;
typedef void (*cactus_token_callback)(const char* token, uint32_t token_id, void* user_data);

cactus_model_t cactus_init(
    const char* model_path,
    const char* corpus_dir,
    bool cache_index
);

void cactus_destroy(cactus_model_t model);
void cactus_reset(cactus_model_t model);
void cactus_stop(cactus_model_t model);

int cactus_set_backend(const char* backend);

int cactus_complete(
    cactus_model_t model,
    const char* messages_json,
    char* response_buffer,
    size_t buffer_size,
    const char* options_json,
    const char* tools_json,
    cactus_token_callback callback,
    void* user_data,
    const uint8_t* pcm_buffer,
    size_t pcm_buffer_size
);

int cactus_prefill(
    cactus_model_t model,
    const char* messages_json,
    char* response_buffer,
    size_t buffer_size,
    const char* options_json,
    const char* tools_json,
    const uint8_t* pcm_buffer,
    size_t pcm_buffer_size
);

int cactus_tokenize(
    cactus_model_t model,
    const char* text,
    uint32_t* token_buffer,
    size_t token_buffer_len,
    size_t* out_token_len
);

int cactus_render_prompt(
    cactus_model_t model,
    const char* messages_json,
    const char* options_json,
    const char* tools_json,
    char* prompt_buffer,
    size_t buffer_size
);

int cactus_embed(
    cactus_model_t model,
    const char* text,
    float* embeddings_buffer,
    size_t buffer_size,
    size_t* embedding_dim,
    bool normalize
);

int cactus_rag_query(
    cactus_model_t model,
    const char* query,
    char* response_buffer,
    size_t buffer_size,
    size_t top_k
);

cactus_index_t cactus_index_init(
    const char* index_dir,
    size_t embedding_dim
);

int cactus_index_add(
    cactus_index_t index,
    const int* ids,
    const char** documents,
    const char** metadatas,
    const float** embeddings,
    size_t count,
    size_t embedding_dim
);

int cactus_index_query(
    cactus_index_t index,
    const float** embeddings,
    size_t embeddings_count,
    size_t embedding_dim,
    const char* options_json,
    int** id_buffers,
    size_t* id_buffer_sizes,
    float** score_buffers,
    size_t* score_buffer_sizes
);

int cactus_index_compact(cactus_index_t index);
void cactus_index_destroy(cactus_index_t index);

const char* cactus_get_last_error(void);

void cactus_log_set_level(int level);

typedef void (*cactus_log_callback_t)(int level, const char* component, const char* message, void* user_data);
void cactus_log_set_callback(cactus_log_callback_t callback, void* user_data);

void cactus_set_telemetry_environment(const char* framework, const char* cache_location, const char* version);
void cactus_set_app_id(const char* app_id);
void cactus_telemetry_flush(void);
void cactus_telemetry_shutdown(void);

#ifdef __cplusplus
}
#endif

#endif /* CACTUS_ENGINE_H */
