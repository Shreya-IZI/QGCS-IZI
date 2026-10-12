#pragma once

#include "QGCOptions.h"

class CustomPlugin;

class CustomOptions : public QGCOptions
{
    Q_OBJECT

public:
    explicit CustomOptions(CustomPlugin *plugin, QObject *parent = nullptr);
    ~CustomOptions() override = default;

    bool checkFirmwareVersion() const override { return false; }

private:
    CustomPlugin *_plugin = nullptr;
};
