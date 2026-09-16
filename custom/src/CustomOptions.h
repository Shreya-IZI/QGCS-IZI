#pragma once

#include "QGCOptions.h"

class CustomPlugin;

class CustomOptions : public QGCOptions
{
    Q_OBJECT

public:
    explicit CustomOptions(CustomPlugin *plugin, QObject *parent = nullptr);
    ~CustomOptions() override = default;

private:
    CustomPlugin *_plugin = nullptr;
};
