import 'package:args/command_runner.dart';

import 'src/optimize/optimize_command.dart';
import 'src/plugin/plugin_command.dart';

final _mockOptimizeCmdArgs = [
  'optimize',
  '--asset-base',
  'http://192.168.101.93:9091/app/',
  '--plugin',
  'scripts/cos_upload_plugin.dart',
];

final _mockPluginCmdArgs = [
  'plugin',
  '--path',
  'scripts/cos_upload_plugin.dart',
];

void main(List<String> arguments) {
  CommandRunner('flutter_web_optimizer', 'app_cli description')
    ..addCommand(PluginCommand())
    ..addCommand(OptimizeCommand())
    // ..run(_mockOptimizeCmdArgs);
    // ..run(_mockPluginCmdArgs);
    ..run(arguments);
}
