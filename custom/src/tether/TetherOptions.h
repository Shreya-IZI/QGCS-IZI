#pragma once

#include "QGCOptions.h"

class TetherPlugin;

class TetherOptions : public QGCOptions
{
    Q_OBJECT

public:
    explicit TetherOptions(TetherPlugin *plugin, QObject *parent = nullptr);
    ~TetherOptions() override = default;

    bool checkFirmwareVersion() const override { return false; }

private:
    TetherPlugin *_plugin = nullptr;
};
