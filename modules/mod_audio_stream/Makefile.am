include $(top_srcdir)/build/modmake.rulesam
MODNAME=mod_audio_stream

mod_LTLIBRARIES = mod_audio_stream.la
mod_audio_stream_la_SOURCES  = mod_audio_stream.c \
                                audio_streamer_glue.cpp \
                                base64.cpp \
                                libs/libwsc/libwsc/WebSocketClient.cpp \
                                libs/libwsc/libwsc/Utf8Validator.cpp \
                                libs/libwsc/libwsc/base64.cpp

mod_audio_stream_la_CFLAGS   = $(AM_CFLAGS)
mod_audio_stream_la_CXXFLAGS = $(AM_CXXFLAGS) -std=c++11 -I$(srcdir)/libs/libwsc/libwsc

mod_audio_stream_la_LIBADD   = $(switch_builddir)/libfreeswitch.la
mod_audio_stream_la_LDFLAGS  = -avoid-version -module -no-undefined -shared -lspeexdsp -lssl -lcrypto -lz -lpthread
