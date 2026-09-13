import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dev_scenario.dart';

final devScenarioProvider = StateProvider<DevScenario>((ref) => DevScenario.normal);
