enum DevScenario { normal, empty, live, offline, pendingRequest, staleGps, fullActivity }

extension DevScenarioX on DevScenario {
  String get label => switch (this) {
    DevScenario.normal => 'Normal',
    DevScenario.empty => 'Ingen aktiviteter',
    DevScenario.live => 'Live aktivitet',
    DevScenario.offline => 'Offline',
    DevScenario.pendingRequest => 'Forespørsel venter',
    DevScenario.staleGps => 'GPS stale',
    DevScenario.fullActivity => 'Full aktivitet',
  };
}
