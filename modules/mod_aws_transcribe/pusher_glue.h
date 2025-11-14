#ifndef __PUSHER_GLUE_H__
#define __PUSHER_GLUE_H__

#ifdef __cplusplus
extern "C" {
#endif

switch_status_t pusher_init();
switch_status_t pusher_cleanup();
switch_status_t pusher_send_transcript(const char* channel_uuid, const char* json_payload);

#ifdef __cplusplus
}
#endif

#endif
