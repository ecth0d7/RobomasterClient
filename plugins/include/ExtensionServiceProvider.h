#pragma once

#include "ServiceEndpoint.h"
#include <QtPlugin>

// Optional interface on a native package's declared service export. This does
// not change ExtensionPackageHost or ExtensionPlugin's existing vtables.
class ExtensionServiceProvider {
public:
    virtual ~ExtensionServiceProvider() = default;
    virtual QString role() const = 0;
    virtual QString contractId() const = 0;
    // Return a NEW, quiescent, unparented endpoint on the calling UI thread.
    // Ownership transfers to the host. Never return the exported provider,
    // reuse a previous endpoint, or delete returned endpoints from stop().
    // Constructors do not connect devices; start()/submit() obey the selected
    // host's independent protocol, consent and provenance admission rules.
    virtual ServiceEndpoint *createService() = 0;
};

#define ExtensionServiceProvider_iid "org.robomaster.client.ExtensionServiceProvider/1.0"
Q_DECLARE_INTERFACE(ExtensionServiceProvider, ExtensionServiceProvider_iid)
