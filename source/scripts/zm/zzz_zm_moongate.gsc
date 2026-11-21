#include common_scripts\utility;
#include maps\mp\_utility;

// Fr0sty - DLC5 additions. Written by Fr0sty; please credit Fr0sty if you reuse or reupload any of this.
// Moon: the teleporter gate (and the Area 51 bunker gate) had no sound. Log lines start with "MOONGATE >>".
// DLC5's zm_moon_teleporter.gsc plays BO1's gate sounds (amb_teleporter_gate_start / _loop / _stop) and the audio is
// in DLC5's Moon bank, but the aliases are never heard. The same three recordings are in mod.ff's dlc5_moongate.all
// bank under new names (dlc5_moongate_start / _loop / _stop, normal 3D sounds), and these are DLC5's own gate functions
// (decompiled) with only the sound names changed, plus BO1 Moon's gate buzzer as a gate starts to open.

main()
{
    if ( getdvar( "mapname" ) != "zm_moon" )
        return;

    moongate_replace( "teleporter_to_nml_gate_move", ::moongate_to_nml_gate_move );
    moongate_replace( "teleporter_exit_nml_gate_move", ::moongate_exit_nml_gate_move );
    moongate_replace( "play_stopmoving_sounds", ::moongate_stopmoving_sounds );
}

init()
{
}

moongate_replace( name, func )
{
    f = getfunction( "maps/mp/zm_moon_teleporter", name );

    if ( isdefined( f ) )
    {
        replacefunc( f, func, -1 );
        println( "MOONGATE >> " + name + " replaced (gate sounds)" );
    }
    else
        println( "MOONGATE >> " + name + " not found" );
}

moongate_to_nml_gate_move( open_it )
{
    if ( level.teleporter_to_nml_gate_open && open_it || !level.teleporter_to_nml_gate_open && !open_it )
        return;

    level.teleporter_to_nml_gate_open = open_it;
    gate_height = level.teleporter_to_nml_gate_height;
    gate2_height = level.teleporter_to_nml_gate2_height;

    if ( !open_it )
        gate_height = gate_height * -1.0;

    time = level.teleporter_gate_move_time;
    accel = time / 6.0;
    ent = level.teleporter_to_nml_gate_ent;
    ent2 = level.teleporter_to_nml_gate2_ent;

    if ( open_it )
        level thread moongate_buzzer( ent );

    ent playsound( "dlc5_moongate_start" );
    ent playloopsound( "dlc5_moongate_loop", 0.5 );
    pos = ( ent.origin[0], ent.origin[1], ent.origin[2] - gate_height );
    ent moveto( pos, time, accel, accel );
    ent thread moongate_stopmoving_sounds();
    pos2 = ( ent2.origin[0], ent2.origin[1], ent2.origin[2] + gate_height );
    ent2 moveto( pos2, time, accel, accel );

    if ( open_it )
        ent connectpaths();
    else
        ent disconnectpaths();

    // looked up at runtime: a direct call to a Moon-only function breaks this script on every other map
    if ( open_it )
        f = getfunction( "maps/mp/zm_moon_teleporter", "teleporter_lights_green" );
    else
        f = getfunction( "maps/mp/zm_moon_teleporter", "teleporter_lights_red" );

    if ( isdefined( f ) )
        [[ f ]]();
}

moongate_exit_nml_gate_move( open_it )
{
    if ( level.teleporter_exit_nml_gate_open && open_it || !level.teleporter_exit_nml_gate_open && !open_it )
        return;

    level.teleporter_exit_nml_gate_open = open_it;
    gate_height = level.teleporter_exit_nml_gate_height;
    gate2_height = level.teleporter_exit_nml_gate2_height;

    if ( !open_it )
    {
        gate_height = gate_height * -1.0;
        gate2_height = gate2_height * -1.0;
    }

    time = level.teleporter_gate_move_time;
    accel = time / 6.0;
    ent = level.teleporter_exit_nml_gate_ent;

    if ( open_it )
        level thread moongate_buzzer( ent );

    ent playsound( "dlc5_moongate_start" );
    ent playloopsound( "dlc5_moongate_loop", 0.5 );
    ent2 = level.teleporter_exit_nml_gate2_ent;
    pos2 = ( ent2.origin[0], ent2.origin[1], ent2.origin[2] - gate2_height );
    ent2 moveto( pos2, time, accel, accel );
    pos = ( ent.origin[0], ent.origin[1], ent.origin[2] - gate_height );
    ent moveto( pos, time, accel, accel );
    ent thread moongate_stopmoving_sounds();

    if ( open_it )
        ent connectpaths();
    else
    {
        wait( level.teleporter_gate_move_time );
        ent disconnectpaths();
    }
}

// BO1 Moon's gate buzzer (amb_teleporter_gate_buzzer = BO1's amb_buzzer recording, in DLC5's Moon bank) as a gate
// starts to open, for the players near that gate (the alias is short-range, so it is played on them)
moongate_buzzer( gate )
{
    players = getplayers();

    for ( i = 0; i < players.size; i++ )
    {
        if ( isdefined( players[i] ) && distancesquared( players[i].origin, gate.origin ) < 3000 * 3000 )
            players[i] playsound( "amb_teleporter_gate_buzzer" );
    }

    println( "MOONGATE >> gate buzzer" );
}

moongate_stopmoving_sounds()
{
    self waittill( "movedone" );
    self stoploopsound( 0.5 );
    self playsound( "dlc5_moongate_stop" );
}
