// Fr0sty - DLC5 additions. Written by Fr0sty; please credit Fr0sty if you reuse or reupload any of this.
// Moon, client side: BO1's Area 51 alarms (see zzz_zm_moonalarm.gsc). Log lines start with "MOONALARM >>".
// BO1's zombie_moon map has 15 "looper" sound structs in Area 51 (No Man's Land): 9 alarm bells (amb_alarm_bell) and
// 6 air-raid sirens (amb_alarm_airraid), looping for the whole game. DLC5's Moon has both aliases (BO1's sounds), but if
// its map doesn't hand those structs to the client they never play. The same emitters are started here at BO1's spots,
// unless the map already has them (then the stock looper code plays them and nothing is doubled).

#include clientscripts\mp\_utility;

main()
{
}

init()
{
    if ( getdvar( "mapname" ) != "zm_moon" )
        return;

    level thread moonalarm_start();
}

moonalarm_start()
{
    wait 1;
    loopers = getstructarray( "looper", "script_label" );

    for ( i = 0; i < loopers.size; i++ )
    {
        if ( isdefined( loopers[i].script_sound ) && ( loopers[i].script_sound == "amb_alarm_bell" || loopers[i].script_sound == "amb_alarm_airraid" ) )
        {
            println( "MOONALARM >> the map already has BO1's alarm loopers (" + loopers.size + " loopers), left alone" );
            return;
        }
    }

    bells = [];
    bells[bells.size] = ( 14045, -13947.5, -310 );
    bells[bells.size] = ( 13491, -13374.5, -310 );
    bells[bells.size] = ( 14617, -13370, -310 );
    bells[bells.size] = ( 15420.5, -14257, -310 );
    bells[bells.size] = ( 12908.5, -14384.5, -310 );
    bells[bells.size] = ( 13502, -14815, -310 );
    bells[bells.size] = ( 14625.5, -14823, -310 );
    bells[bells.size] = ( 14557, -15454, -310 );
    bells[bells.size] = ( 13542, -15473.5, -310 );

    sirens = [];
    sirens[sirens.size] = ( 14042.5, -12698, -310 );
    sirens[sirens.size] = ( 12952.5, -14214, -310 );
    sirens[sirens.size] = ( 15482.5, -13513.5, -310 );
    sirens[sirens.size] = ( 15227.5, -15552, -310 );
    sirens[sirens.size] = ( 13107.5, -16529.5, -310 );
    sirens[sirens.size] = ( 12238, -15382, -310 );

    for ( i = 0; i < bells.size; i++ )
        soundloopemitter( "amb_alarm_bell", bells[i] );

    for ( i = 0; i < sirens.size; i++ )
        soundloopemitter( "amb_alarm_airraid", sirens[i] );

    println( "MOONALARM >> BO1 Area 51 alarms on: " + bells.size + " bells, " + sirens.size + " air-raid sirens (map had " + loopers.size + " loopers)" );
}
