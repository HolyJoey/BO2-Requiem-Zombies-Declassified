// Fr0sty - DLC5 additions. Written by Fr0sty; please credit Fr0sty if you reuse or reupload any of this.
// DLC5 Moon: "No Man's Land" start location.
// Stage 1 (now): probe the map so we can see what the teleporter is actually made of.
//   The log lines start with "MOONNML >>".
// Stage 2 (after the probe): disable the teleporter when the chosen start location is nomansland.

main()
{
}

init()
{
    if ( getdvar( "mapname" ) != "zm_moon" )
        return;

    level thread moonnml_block_teleporter();
}

moonnml_probe()
{
    level endon( "end_game" );
    wait 2;

    startloc = getdvar( "ui_zm_mapstartlocation" );
    println( "MOONNML >> start location = '" + startloc + "'" );

    moonnml_list_ents( "trigger_use", "classname" );
    moonnml_list_ents( "trigger_radius", "classname" );
    moonnml_list_ents( "trigger_multiple", "classname" );
    moonnml_list_ents( "script_model", "classname" );

    moonnml_list_by_name( "tele" );
    moonnml_list_by_name( "pad" );
    moonnml_list_by_name( "portal" );
    moonnml_list_by_name( "jump" );
    moonnml_list_by_name( "launch" );

    println( "MOONNML >> probe done" );
}

moonnml_list_ents( value, key )
{
    ents = getentarray( value, key );
    count = 0;
    shown = 0;

    foreach ( ent in ents )
    {
        if ( !isdefined( ent ) )
            continue;

        count++;
        name = "";

        if ( isdefined( ent.targetname ) )
            name = ent.targetname;

        target = "";

        if ( isdefined( ent.target ) )
            target = ent.target;

        script_noteworthy = "";

        if ( isdefined( ent.script_noteworthy ) )
            script_noteworthy = ent.script_noteworthy;

        // only print the interesting ones, there can be hundreds
        if ( shown < 40 && ( moonnml_interesting( name ) || moonnml_interesting( target ) || moonnml_interesting( script_noteworthy ) ) )
        {
            shown++;
            println( "MOONNML >> " + key + "=" + value + " targetname='" + name + "' target='" + target + "' noteworthy='" + script_noteworthy + "' at " + ent.origin );
        }
    }

    println( "MOONNML >> " + value + ": " + count + " ent(s), " + shown + " interesting" );
}

moonnml_interesting( text )
{
    if ( !isdefined( text ) || text == "" )
        return false;

    lower = tolower( text );

    return issubstr( lower, "tele" ) || issubstr( lower, "pad" ) || issubstr( lower, "portal" ) || issubstr( lower, "jump" ) || issubstr( lower, "launch" ) || issubstr( lower, "moon" );
}

moonnml_list_by_name( needle )
{
    ents = getentarray();
    shown = 0;

    foreach ( ent in ents )
    {
        if ( !isdefined( ent ) || !isdefined( ent.targetname ) )
            continue;

        if ( shown >= 25 )
            break;

        if ( issubstr( tolower( ent.targetname ), needle ) )
        {
            shown++;
            classname = "";

            if ( isdefined( ent.classname ) )
                classname = ent.classname;

            println( "MOONNML >> name~'" + needle + "': targetname='" + ent.targetname + "' classname='" + classname + "' at " + ent.origin );
        }
    }

    println( "MOONNML >> name~'" + needle + "': " + shown + " match(es)" );
}

// Probe 2: what is around the No Man's Land teleporter, and where do players actually stand.
moonnml_probe2()
{
    level endon( "end_game" );
    wait 4;

    volume = getent( "nml_teleporter", "targetname" );

    if ( isdefined( volume ) )
        println( "MOONNML2 >> nml_teleporter volume at " + volume.origin + " angles " + volume.angles );
    else
        println( "MOONNML2 >> nml_teleporter NOT found" );

    // every trigger_use in the map, with its distance to that volume
    trigs = getentarray( "trigger_use", "classname" );

    foreach ( trig in trigs )
    {
        if ( !isdefined( trig ) )
            continue;

        name = "";

        if ( isdefined( trig.targetname ) )
            name = trig.targetname;

        dist = "n/a";

        if ( isdefined( volume ) )
            dist = "" + int( distance( trig.origin, volume.origin ) );

        println( "MOONNML2 >> trigger_use '" + name + "' at " + trig.origin + " dist_to_nml_tele=" + dist );
    }

    // and the trigger_damage/hurt + brushmodels near the teleporter
    foreach ( kind in array( "trigger_hurt", "script_brushmodel", "info_volume" ) )
    {
        ents = getentarray( kind, "classname" );
        shown = 0;

        foreach ( ent in ents )
        {
            if ( !isdefined( ent ) || shown >= 15 )
                continue;

            if ( isdefined( volume ) && distance( ent.origin, volume.origin ) > 2000 )
                continue;

            shown++;
            name = "";

            if ( isdefined( ent.targetname ) )
                name = ent.targetname;

            println( "MOONNML2 >> near teleporter: " + kind + " '" + name + "' at " + ent.origin );
        }
    }

    // where the players are, so we know the Area 51 area in map coordinates
    for ( i = 0; i < 10; i++ )
    {
        players = getplayers();

        if ( players.size > 0 && isdefined( players[0] ) )
            println( "MOONNML2 >> player at " + players[0].origin + " t=" + i * 10 + "s" );

        wait 10;
    }

    println( "MOONNML2 >> probe 2 done" );
}

// Keep the players in Area 51: the teleporter to the moon is disabled for this start location.
moonnml_block_teleporter()
{
    level endon( "end_game" );
    wait 3;

    if ( getdvar( "ui_zm_mapstartlocation" ) != "nomansland" )
    {
        println( "MOONNML >> normal Moon start, teleporter left alone" );
        return;
    }

    // 1. push the teleporter trigger volume out of the world so nothing can touch it
    volume = getent( "nml_teleporter", "targetname" );

    if ( isdefined( volume ) )
    {
        volume.origin = volume.origin + ( 0, 0, -100000 );
        println( "MOONNML >> nml_teleporter volume moved out of reach" );
    }
    else
        println( "MOONNML >> nml_teleporter volume not found" );

    // 2. safety net in case the map teleports players some other way.
    //    Area 51 sits around x = 14000, the moon areas are near x = 0.
    level thread moonnml_keep_players_in_area51();
}

moonnml_keep_players_in_area51()
{
    level endon( "end_game" );

    for (;;)
    {
        players = getplayers();

        foreach ( player in players )
        {
            if ( !isdefined( player ) || !isalive( player ) )
                continue;

            if ( player.origin[0] > 10000 )
            {
                player.nml_last_safe = player.origin;
                continue;
            }

            if ( !isdefined( player.nml_last_safe ) )
                continue;

            player setorigin( player.nml_last_safe );
            println( "MOONNML >> " + player.name + " left Area 51, put back at " + player.nml_last_safe );
        }

        wait 0.5;
    }
}
