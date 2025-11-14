#include <switch.h>
#include <curl/curl.h>
#include <openssl/hmac.h>
#include <openssl/sha.h>
#include <string>
#include <sstream>
#include <iomanip>
#include <ctime>
#include <cJSON.h>

#include "pusher_glue.h"

// Pusher configuration
static std::string pusherAppId;
static std::string pusherKey;
static std::string pusherSecret;
static std::string pusherCluster;
static bool pusherEnabled = false;

// HTTP/2 connection pool
static CURLM *multi_handle = NULL;
static bool curl_initialized = false;

// Helper function to generate HMAC-SHA256 signature
static std::string hmac_sha256(const std::string& key, const std::string& data) {
    unsigned char* digest = HMAC(EVP_sha256(),
                                  key.c_str(), key.length(),
                                  (unsigned char*)data.c_str(), data.length(),
                                  NULL, NULL);

    std::stringstream ss;
    for(int i = 0; i < SHA256_DIGEST_LENGTH; i++) {
        ss << std::hex << std::setw(2) << std::setfill('0') << (int)digest[i];
    }

    return ss.str();
}

// Helper function to get current timestamp
static std::string get_timestamp() {
    std::time_t now = std::time(nullptr);
    std::stringstream ss;
    ss << now;
    return ss.str();
}

// Helper function to compute MD5 hash (for body)
static std::string md5_hash(const std::string& data) {
    unsigned char digest[MD5_DIGEST_LENGTH];
    MD5((unsigned char*)data.c_str(), data.length(), digest);

    std::stringstream ss;
    for(int i = 0; i < MD5_DIGEST_LENGTH; i++) {
        ss << std::hex << std::setw(2) << std::setfill('0') << (int)digest[i];
    }

    return ss.str();
}

// Callback for curl response
static size_t write_callback(void *contents, size_t size, size_t nmemb, void *userp) {
    ((std::string*)userp)->append((char*)contents, size * nmemb);
    return size * nmemb;
}

extern "C" {

switch_status_t pusher_init() {
    const char* app_id = std::getenv("PUSHER_APP_ID");
    const char* key = std::getenv("PUSHER_KEY");
    const char* secret = std::getenv("PUSHER_SECRET");
    const char* cluster = std::getenv("PUSHER_CLUSTER");

    if (app_id && key && secret && cluster) {
        pusherAppId = app_id;
        pusherKey = key;
        pusherSecret = secret;
        pusherCluster = cluster;
        pusherEnabled = true;

        // Initialize libcurl globally
        if (!curl_initialized) {
            curl_global_init(CURL_GLOBAL_ALL);
            multi_handle = curl_multi_init();

            // Enable HTTP/2 multiplexing
            curl_multi_setopt(multi_handle, CURLMOPT_PIPELINING, CURLPIPE_MULTIPLEX);

            curl_initialized = true;
        }

        switch_log_printf(SWITCH_CHANNEL_LOG, SWITCH_LOG_NOTICE,
            "Pusher REST API integration enabled (app_id: %s, key: %s..., cluster: %s)\n",
            app_id, std::string(key).substr(0, 8).c_str(), cluster);

        return SWITCH_STATUS_SUCCESS;
    } else {
        switch_log_printf(SWITCH_CHANNEL_LOG, SWITCH_LOG_INFO,
            "Pusher environment variables not set (PUSHER_APP_ID, PUSHER_KEY, PUSHER_SECRET, PUSHER_CLUSTER). "
            "Pusher integration disabled.\n");
        pusherEnabled = false;
        return SWITCH_STATUS_FALSE;
    }
}

switch_status_t pusher_cleanup() {
    pusherEnabled = false;

    if (multi_handle) {
        curl_multi_cleanup(multi_handle);
        multi_handle = NULL;
    }

    if (curl_initialized) {
        curl_global_cleanup();
        curl_initialized = false;
    }

    return SWITCH_STATUS_SUCCESS;
}

switch_status_t pusher_send_transcript(const char* channel_uuid, const char* json_payload) {
    if (!pusherEnabled) {
        return SWITCH_STATUS_FALSE;
    }

    // Build channel name
    std::string channel = std::string("transcription-") + channel_uuid;
    std::string event_name = "transcript";

    // Create request body
    cJSON* body = cJSON_CreateObject();
    cJSON_AddStringToObject(body, "name", event_name.c_str());
    cJSON_AddStringToObject(body, "channel", channel.c_str());
    cJSON_AddStringToObject(body, "data", json_payload);

    char* body_str = cJSON_PrintUnformatted(body);
    std::string body_json(body_str);
    free(body_str);
    cJSON_Delete(body);

    // Compute body MD5
    std::string body_md5 = md5_hash(body_json);

    // Build authentication string
    std::string timestamp = get_timestamp();
    std::string method = "POST";
    std::string path = "/apps/" + pusherAppId + "/events";

    std::stringstream auth_string;
    auth_string << method << "\n"
                << path << "\n"
                << "auth_key=" << pusherKey
                << "&auth_timestamp=" << timestamp
                << "&auth_version=1.0"
                << "&body_md5=" << body_md5;

    // Generate auth signature
    std::string auth_signature = hmac_sha256(pusherSecret, auth_string.str());

    // Build full URL with query parameters
    std::stringstream url;
    url << "https://api-" << pusherCluster << ".pusher.com" << path
        << "?auth_key=" << pusherKey
        << "&auth_timestamp=" << timestamp
        << "&auth_version=1.0"
        << "&body_md5=" << body_md5
        << "&auth_signature=" << auth_signature;

    // Initialize curl handle
    CURL *curl = curl_easy_init();
    if (!curl) {
        switch_log_printf(SWITCH_CHANNEL_LOG, SWITCH_LOG_ERROR,
            "Failed to initialize curl handle for Pusher request\n");
        return SWITCH_STATUS_FALSE;
    }

    std::string response;
    struct curl_slist *headers = NULL;
    headers = curl_slist_append(headers, "Content-Type: application/json");

    // Configure curl request
    curl_easy_setopt(curl, CURLOPT_URL, url.str().c_str());
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body_json.c_str());
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
    curl_easy_setopt(curl, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_2_0);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 5L);

    // Perform request
    CURLcode res = curl_easy_perform(curl);

    if (res != CURLE_OK) {
        switch_log_printf(SWITCH_CHANNEL_LOG, SWITCH_LOG_ERROR,
            "Failed to send Pusher event: %s\n", curl_easy_strerror(res));
        curl_slist_free_all(headers);
        curl_easy_cleanup(curl);
        return SWITCH_STATUS_FALSE;
    }

    long http_code = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);

    if (http_code != 200) {
        switch_log_printf(SWITCH_CHANNEL_LOG, SWITCH_LOG_ERROR,
            "Pusher API returned HTTP %ld: %s\n", http_code, response.c_str());
        curl_slist_free_all(headers);
        curl_easy_cleanup(curl);
        return SWITCH_STATUS_FALSE;
    }

    switch_log_printf(SWITCH_CHANNEL_LOG, SWITCH_LOG_DEBUG,
        "Successfully sent transcript to Pusher channel %s\n", channel.c_str());

    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);

    return SWITCH_STATUS_SUCCESS;
}

} // extern "C"
