// Fr0sty - DLC5 additions. Written by Fr0sty; please credit Fr0sty if you reuse or reupload any of this.
// Moon: BO1's Area 51 alarms instead of the Der Riese buzzer. Log lines start with "MOONALARM >>".
// DLC5's zzz_zm_moonbuzzer.gsc (Logo2K, usermaps\zm_moon) plays amb_teleporter_gate_buzzer - the Der Riese teleporter
// buzzer (amb_buzzer) - every time the Area 51 gate rises. BO1's Moon never plays that buzzer; Area 51 has BO1's alarm
// bells and air-raid sirens instead (zzz_zm_moonalarm.csc). This switches the buzzer off on Moon only; the alias and
// Der Riese's own buzzer are untouched, and Logo2K's file is not changed.

main()
{
    if ( getdvar( "mapname" ) != "zm_moon" )
        return;

    f = getfunction( "scripts/zm/zzz_zm_moonbuzzer", "moonbuzzer_watch" );

    if ( isdefined( f ) )
    {
        replacefunc( f, ::moonalarm_no_buzzer, -1 );
        println( "MOONALARM >> Der Riese buzzer switched off on Moon (BO1 alarms play instead)" );
    }
    else
        println( "MOONALARM >> zzz_zm_moonbuzzer not found, nothing to switch off" );
}

init()
{
}

moonalarm_no_buzzer()
{
}
