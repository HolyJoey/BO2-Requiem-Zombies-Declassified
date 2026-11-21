#include common_scripts\utility;
#include maps\mp\_utility;

// Fr0sty - DLC5 additions. Written by Fr0sty; please credit Fr0sty if you reuse or reupload any of this.
// Moon: the Earth in the sky (and the destroyed Earth after the Easter egg). Log lines start with "MOONEARTH >>".
// BO1 draws the Earth as a client-side model that zombie_moon.csc spawns when the server sends "S_E" (and removes on
// "H_E"; "SDE" = destroyed Earth). BO1's sidequest sent those on every No Man's Land <-> Moon teleport; the DLC5
// any-player EE script replaced that with a server-side level.earth that does not exist here, so the Earth never
// showed. This watches the state and zzz_zm_moonearth.csc draws it (own notify names, so nothing doubles up).
// Drawn as pre-shrunk copies (p_dlc5_moon_earth / _dest in mod_patch) near the player - see the .csc.
// (The X360 map has it as a plain map entity at BO1's spot; recreated on PC it stays invisible - BO2 PC does not
// draw anything that far out - so the client draws a scaled copy at a visible distance instead.)
//   in No Man's Land (flag enter_nml)          -> no Earth
//   on the Moon                                -> Earth
//   on the Moon after the EE (level._dte_done) -> destroyed Earth

main()
{
    if ( getdvar( "mapname" ) != "zm_moon" )
        return;

    // the client draws these; a client model has to be precached by the server first
    precachemodel( "p_dlc5_moon_earth" );
    precachemodel( "p_dlc5_moon_earth_dest" );
}

init()
{
    if ( getdvar( "mapname" ) != "zm_moon" )
        return;

    level thread moonearth_watch();
    level thread moonearth_joiners();
}

moonearth_state()
{
    if ( isdefined( level.flag ) && isdefined( level.flag["enter_nml"] ) && flag( "enter_nml" ) )
        return "none";

    if ( isdefined( level._dte_done ) && level._dte_done )
        return "dest";

    return "earth";
}

moonearth_send( state )
{
    if ( state == "none" )
    {
        level clientnotify( "dlc5_he" );
        setdvar( "r_zombieDisableEarthEffect", 1 );
    }
    else if ( state == "dest" )
    {
        level clientnotify( "dlc5_sde" );
        setdvar( "r_zombieDisableEarthEffect", 0 );
    }
    else
    {
        level clientnotify( "dlc5_se" );
        setdvar( "r_zombieDisableEarthEffect", 0 );
    }
}

moonearth_watch()
{
    level endon( "end_game" );

    while ( getplayers().size == 0 )
        wait 0.1;

    wait 1;
    level.moonearth_state = "";

    for (;;)
    {
        state = moonearth_state();

        if ( state != level.moonearth_state )
        {
            level.moonearth_state = state;
            moonearth_send( state );
            println( "MOONEARTH >> " + state );
        }

        wait 0.25;
    }
}

// a player joining late never got the last notify: send the current state again (the client replaces its model)
moonearth_joiners()
{
    level endon( "end_game" );

    for (;;)
    {
        level waittill( "connected", player );
        wait 3;

        if ( isdefined( level.moonearth_state ) && level.moonearth_state != "" )
            moonearth_send( level.moonearth_state );
    }
}
