import 'app_info.dart';
import '../data/models.dart';

String signPuddleSvgUrl(String sign, SignKind kind) {
  final encoded = Uri.encodeComponent(sign);
  final path = kind == SignKind.fsw ? 'fsw' : 'swu';
  return '${AppInfo.signPuddleServer}/$path/svg/$encoded';
}

String signPuddleEntryUrl(int id) =>
    '${AppInfo.signPuddleClient}#/dictionary/${AppInfo.dictionaryName}/entry/$id';
