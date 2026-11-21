// Fr0sty - DLC5 additions. Written by Fr0sty; please credit Fr0sty if you reuse or reupload any of this.
// DLC5 extras (every map). Log lines start with "DLC5EXTRA >>".
//   Nukes kill dogs: the stock nuke only collects getaiarray( zombie_team ), which leaves hellhounds out.
//   One Ray Gun at a time: holding the Ray Gun (or its upgrade) keeps the Mark 2 out of the box, and the other way
//   round (chained onto any special_weapon_magicbox_check the map already set).
//   Ray Gun Mark 2 shots: other players never heard them, so the server relays each shot's npc sound to everyone
//   but the shooter (who keeps their own first-person sound).
//   Bonfire Sale announcer line: stock BO2 has no announcer entry for it, so it is added (only where missing) and
//   points at vox_zmba_powerup_bonfiresale_*, which the dlc5_bo1vox.english bank in mod.ff supplies from BO1.

main()
{
}

init()
{
    println( "DLC5EXTRA >> DLC5 additions by Fr0sty" );
    level thread dlc5x_nuke_dogs();
    level thread dlc5x_raygun_lock();
    level thread dlc5x_players();
    level thread dlc5x_bonfire_vox();
}

dlc5x_bonfire_vox()
{
    level endon( "end_game" );

    while ( getplayers().size == 0 )
        wait 0.1;

    wait 2;
    added = "";

    // never point the game at a sound that isn't there (no bank = leave everything stock)
    if ( !soundexists( "vox_zmba_powerup_bonfiresale_0" ) )
    {
        println( "DLC5EXTRA >> bonfire sale announcer line: sound not loaded, left stock" );
        return;
    }

    // _zm_audio_announcer::leaderdialog path (game["zmbdialog"])
    if ( isdefined( game["zmbdialog"] ) && !isdefined( game["zmbdialog"]["bonfire_sale"] ) )
    {
        game["zmbdialog"]["bonfire_sale"] = "powerup_bonfiresale";
        added = added + " leaderdialog";
    }

    // _zm_audio::do_announcer_playvox path (level.vox announcer table), only if this map uses it for powerups
    if ( isdefined( level.vox ) && isdefined( level.vox.speaker ) && isdefined( level.vox.speaker["announcer"] ) && isdefined( level.vox.speaker["announcer"].alias["powerup"] ) && !isdefined( level.vox.speaker["announcer"].alias["powerup"]["bonfire_sale"] ) )
    {
        level.vox.speaker["announcer"].alias["powerup"]["bonfire_sale"] = "powerup_bonfiresale";
        added = added + " announcer_table";
    }

    if ( added == "" )
        added = " nothing (already there)";

    println( "DLC5EXTRA >> bonfire sale announcer line:" + added + ", sound exists " + soundexists( "vox_zmba_powerup_bonfiresale_0" ) );
}

dlc5x_nuke_dogs()
{
    level endon( "end_game" );

    for (;;)
    {
        level waittill( "powerup_dropped", powerup );

        if ( isdefined( powerup ) && isdefined( powerup.powerup_name ) && powerup.powerup_name == "nuke" )
            powerup thread dlc5x_nuke_watch();
    }
}

dlc5x_nuke_watch()
{
    self endon( "powerup_timedout" );
    self endon( "death" );
    self waittill( "powerup_grabbed" );

    // the stock nuke starts killing 0.5s after the grab; follow it
    wait 0.6;
    team = "axis";

    if ( isdefined( level.zombie_team ) )
        team = level.zombie_team;

    dogs = getaispeciesarray( team, "zombie_dog" );
    killed = 0;

    foreach ( dog in dogs )
    {
        if ( !isdefined( dog ) || !isalive( dog ) )
            continue;

        dog.nuked = 1;
        dog dodamage( dog.health + 666, dog.origin );
        killed++;
        wait randomfloatrange( 0.05, 0.15 );
    }

    println( "DLC5EXTRA >> nuke killed " + killed + " dogs" );
}

dlc5x_raygun_lock()
{
    level endon( "end_game" );

    // the map sets its own hooks during load; wrap whatever is there once the game is running
    while ( getplayers().size == 0 )
        wait 0.1;

    wait 5;
    level.dlc5x_prev_box_check = level.special_weapon_magicbox_check;
    level.special_weapon_magicbox_check = ::dlc5x_box_check;
    println( "DLC5EXTRA >> ray gun / mark 2 box lock armed" );
}

// self = the player spinning the box
dlc5x_box_check( weapon )
{
    if ( dlc5x_is_raygun( weapon ) && ( self hasweapon( "raygun_mark2_zm" ) || self hasweapon( "raygun_mark2_upgraded_zm" ) ) )
        return 0;

    if ( dlc5x_is_mark2( weapon ) && ( self hasweapon( "ray_gun_zm" ) || self hasweapon( "ray_gun_upgraded_zm" ) ) )
        return 0;

    if ( isdefined( level.dlc5x_prev_box_check ) )
        return self [[ level.dlc5x_prev_box_check ]]( weapon );

    return 1;
}

dlc5x_is_raygun( weapon )
{
    return weapon == "ray_gun_zm" || weapon == "ray_gun_upgraded_zm";
}

dlc5x_is_mark2( weapon )
{
    return weapon == "raygun_mark2_zm" || weapon == "raygun_mark2_upgraded_zm";
}

dlc5x_players()
{
    level endon( "end_game" );

    for (;;)
    {
        level waittill( "connected", player );
        player thread dlc5x_mark2_relay();
    }
}

dlc5x_mark2_relay()
{
    self endon( "disconnect" );

    for (;;)
    {
        self waittill( "weapon_fired" );
        weapon = self getcurrentweapon();

        if ( !dlc5x_is_mark2( weapon ) )
            continue;

        foreach ( other in getplayers() )
        {
            if ( isdefined( other ) && other != self )
                self playsoundtoplayer( "wpn_rgunmk2_fire_npc", other );
        }
    }
}
