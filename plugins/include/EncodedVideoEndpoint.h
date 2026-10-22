#pragma once
#include "ClientPlugin.h"

// Optional interfaces; existing ClientPlugin/VideoEndpoint vtables are unchanged.
// The host calls these on the endpoint's UI thread. Accepted bytes are queued,
// not proof that a frame was decoded. A discontinuity retires all prior images.
class EncodedVideoInput {
public:
    virtual ~EncodedVideoInput() = default;
    virtual bool submitEncoded(const QByteArray &bytes, bool discontinuity) = 0;
};
#define EncodedVideoInput_iid "org.robomaster.client.EncodedVideoInput/1.0"
Q_DECLARE_INTERFACE(EncodedVideoInput, EncodedVideoInput_iid)

class EncodedVideoFactory {
public:
    virtual ~EncodedVideoFactory() = default;
    // New unparented endpoint, with bounded input and no socket/device opened.
    virtual VideoEndpoint *createEncodedVideo(const QVariantMap &configuration) = 0;
};
#define EncodedVideoFactory_iid "org.robomaster.client.EncodedVideoFactory/1.0"
Q_DECLARE_INTERFACE(EncodedVideoFactory, EncodedVideoFactory_iid)
