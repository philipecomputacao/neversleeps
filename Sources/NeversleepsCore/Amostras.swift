// Amostras.swift — saidas REAIS do pmset, capturadas num MacBookPro17,1 (M1),
// macOS 26.2, em 12/09/2026. Usadas pelos testes (CI) e pelo alvo `verificar`
// (local). Se o formato mudar numa versao futura do macOS, acrescente a saida
// nova aqui e mantenha a antiga: o parser precisa ler as duas.

public enum Amostras {
    public static let custom = """
    Battery Power:
     Sleep On Power Button 1
     lowpowermode         0
     standby              1
     ttyskeepawake        1
     hibernatemode        3
     powernap             1
     hibernatefile        /var/vm/sleepimage
     displaysleep         0
     womp                 0
     networkoversleep     0
     sleep                1
     lessbright           1
     tcpkeepalive         1
     disksleep            10
    AC Power:
     Sleep On Power Button 1
     lowpowermode         0
     standby              1
     ttyskeepawake        1
     hibernatemode        3
     powernap             1
     hibernatefile        /var/vm/sleepimage
     displaysleep         0
     womp                 1
     networkoversleep     0
     sleep                1
     tcpkeepalive         1
     disksleep            10
    """

    /// `pmset -g` inclui a anotacao "(sleep prevented by ...)" na linha do sleep.
    public static let geral = """
    System-wide power settings:
    Currently in use:
     standby              1
     Sleep On Power Button 1
     hibernatefile        /var/vm/sleepimage
     powernap             1
     networkoversleep     0
     disksleep            10
     sleep                1 (sleep prevented by powerd, Claude, sharingd)
     hibernatemode        3
     ttyskeepawake        1
     displaysleep         0
     tcpkeepalive         1
     lowpowermode         0
     womp                 1
    """

    public static let geralComTrava = "System-wide power settings:\n SleepDisabled\t\t1\nCurrently in use:\n sleep 1\n"
    public static let geralSemTrava = "System-wide power settings:\n SleepDisabled\t\t0\nCurrently in use:\n sleep 1\n"

    public static let battBateria = "Now drawing from 'Battery Power'\n -InternalBattery-0 (id=22806627)\t78%; discharging; 5:05 remaining present: true\n"
    public static let battTomada  = "Now drawing from 'AC Power'\n -InternalBattery-0 (id=22806627)\t83%; charging; 1:00 remaining present: true\n"

    /// Trecho real do log, com o repouso por tampa fechada de 12/09 as 09:09.
    public static let log = """
    2026-09-12 07:15:00 -0300 Sleep               \tEntering Sleep state due to 'Maintenance Sleep':TCPKeepAlive=active Using Batt (Charge:100%) 92 secs
    2026-09-12 09:09:08 -0300 Notification        \tDisplay is turned off
    2026-09-12 09:09:13 -0300 Sleep               \tEntering Sleep state due to 'Clamshell Sleep':TCPKeepAlive=active Using AC (Charge:84%) 59 secs
    2026-09-12 09:10:12 -0300 Wake                \tWake from Deep Idle [CDNVA] : due to smc.sysState.Wake(0x70070000) lid SMC.OutboxNotEmpty/UserActivity Assertion Using AC (Charge:84%)
    2026-09-12 09:10:12 -0300 Notification        \tDisplay is turned on
    """
}
