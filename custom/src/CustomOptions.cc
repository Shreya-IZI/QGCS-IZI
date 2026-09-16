#include "CustomOptions.h"
#include "CustomPlugin.h"

CustomOptions::CustomOptions(CustomPlugin *plugin, QObject *parent)
    : QGCOptions(parent)
    , _plugin(plugin)
{
}
