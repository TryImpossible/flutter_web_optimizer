import 'package:args/command_runner.dart';

import 'src/optimize/optimize_command.dart';
import 'src/plugin/plugin_command.dart';

final _mockOptimizeCmdArgs = [
  'optimize',
  '--asset-base',
  'http://test-app-1251021022.cos.ap-guangzhou.myqcloud.com/manbumata/dev/',
  '--plugin',
  'scripts/cos_upload_plugin.dart',
];

void main(List<String> arguments) {
  CommandRunner('flutter_web_optimizer', 'app_cli description')
    ..addCommand(PluginCommand())
    ..addCommand(OptimizeCommand())
    // ..run(_mockChannelCmdArgs);
    ..run(arguments);
}
