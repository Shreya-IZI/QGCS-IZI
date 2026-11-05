#include "TetherOptions.h"

TetherOptions::TetherOptions(TetherPlugin *plugin, QObject *parent)
    : QGCOptions(parent)
    , _plugin(plugin)
{
}
