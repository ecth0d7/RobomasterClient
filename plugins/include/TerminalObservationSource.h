#pragma once

#include "PacketObservation.h"
#include <QObject>
#include <QVariantMap>
#include <QtPlugin>

// Optional native-only extension of a package context. It deliberately remains
// separate from ExtensionPackageHost's vtable and is not a QML injection API.
// A source package declares terminal.sources@3, and saves team_id / robot_key
// in its user-reviewed configuration before requesting a registration.
class TerminalObservationSourceFactory {
public:
    virtual ~TerminalObservationSourceFactory() = default;
    virtual QObject *openObservationSource(const QVariantMap &descriptor, QString *error = nullptr) = 0;
};

// Descriptor input: source_id, sensor_id, source_kind and clock_domain.
// Identity, rules context, package provenance, source namespace and session are
// stamped by the host. They cannot be overwritten by an individual sample.
// All calls run on the source's owning thread. Workers capture ingress timing
// before queueing a bounded callback to their package session, and must stop
// before the session returns from stop(). Pointers are valid only for that
// activation; retaining one never grants a new source session after retirement.
class TerminalObservationSource {
public:
    virtual ~TerminalObservationSource() = default;
    virtual QVariantMap descriptor() const = 0;
    virtual bool submit(const QVariantMap &sample, const PacketObservation::Stamp &ingress,
                        QString *error = nullptr) = 0;
    virtual void close() noexcept = 0;
};

#define TerminalObservationSourceFactory_iid "org.robomaster.client.TerminalObservationSourceFactory/3.0"
#define TerminalObservationSource_iid "org.robomaster.client.TerminalObservationSource/3.0"
Q_DECLARE_INTERFACE(TerminalObservationSourceFactory, TerminalObservationSourceFactory_iid)
Q_DECLARE_INTERFACE(TerminalObservationSource, TerminalObservationSource_iid)
