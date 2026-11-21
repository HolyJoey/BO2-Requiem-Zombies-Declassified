#include common_scripts\utility;
#include maps\mp\_utility;

// Fr0sty - DLC5 additions. Written by Fr0sty; please credit Fr0sty if you reuse or reupload any of this.
// Moon (normal start): the Area 51 perk machine (Jugg or Speed Cola, the map picks one) is always powered, like BO1's
// turn_area51_perks_on(). Log lines start with "MOONA51POWER >>".
// DLC5's zzz_zm_moona51perks.gsc (Logo2K) sends the "specialty_..._power_on" notice once, 1 second in. That is the
// notice stock sends *after* powering a machine, so when it lands before the stock perk loop has started, the machine
// goes back to its off model and its trigger never gets the buy prompt - random from game to game. This sends stock's
// real switch ("juggernog_on" / "sleight_on", the same one the power switch uses) until the Area 51 machine is powered,
// and again if anything turns it off. Only Area 51 machines: if the Moon itself has a machine of the same perk, that
// perk is left alone (its switch would power both). No Man's Land start has its own handling (zzz_nmlperks.gsc).

main()
{
}

init()
{
    if ( getdvar( "mapname" ) != "zm_moon" )
        return;

    level thread a51power_watch();
}

a51power_in_area51( origin )
{
    // Area 51 / No Man's Land hangar (BO1 coordinates, the same in DLC5's map)
    return origin[0] > 10000 && origin[0] < 18000 && origin[1] > -19000 && origin[1] < -10000 && origin[2] > -2000 && origin[2] < 1000;
}

a51power_watch()
{
    level endon( "end_game" );
    flag_wait( "initial_blackscreen_passed" );

    if ( getdvar( "ui_zm_mapstartlocation" ) == "nomansland" )
        return;

    perks = [];
    perks[perks.size] = "specialty_armorvest";
    perks[perks.size] = "specialty_fastreload";
    switches = [];
    switches["specialty_armorvest"] = "juggernog_on";
    switches["specialty_fastreload"] = "sleight_on";
    logged = [];

    for (;;)
    {
        foreach ( perk in perks )
        {
            a51 = [];
            elsewhere = 0;

            foreach ( trig in getentarray( "zombie_vending", "targetname" ) )
            {
                if ( !isdefined( trig.script_noteworthy ) || trig.script_noteworthy != perk )
                    continue;

                // the machine the map did not pick is parked far below the map
                if ( trig.origin[2] < -5000 )
                    continue;

                if ( a51power_in_area51( trig.origin ) )
                    a51[a51.size] = trig;
                else
                    elsewhere = 1;
            }

            if ( a51.size == 0 )
                continue;

            if ( elsewhere )
            {
                if ( !isdefined( logged[perk] ) )
                {
                    logged[perk] = 1;
                    println( "MOONA51POWER >> " + perk + " also has a machine on the Moon - left to the power switch" );
                }

                continue;
            }

            powered = 1;

            foreach ( trig in a51 )
            {
                if ( !( isdefined( trig.power_on ) && trig.power_on ) )
                    powered = 0;
            }

            if ( !powered )
            {
                level notify( switches[perk] );

                if ( !isdefined( logged[perk + "_on"] ) )
                {
                    logged[perk + "_on"] = 1;
                    println( "MOONA51POWER >> Area 51 " + perk + " was unpowered, sent " + switches[perk] );
                }
            }
        }

        wait 1;
    }
}
