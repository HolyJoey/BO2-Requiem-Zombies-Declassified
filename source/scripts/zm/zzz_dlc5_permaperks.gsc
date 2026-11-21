// Fr0sty - DLC5 additions. Written by Fr0sty; please credit Fr0sty if you reuse or reupload any of this.
// Perma perks on DLC5 maps, a lobby option that is on by default (dvar dlc5_permaperks; "0" = off). Log lines start with "PERMAPERKS >>".
// Stock registers each perma perk only if the map set level.pers_upgrade_<name> (Tranzit / Die Rise / Buried do);
// the DLC5 maps set none, so _zm_pers_upgrades::pers_upgrade_init registers nothing and its monitor quits at once.
// Here every flag is set; if stock has already run its init with none of them, it is run again once the game is up
// (the first monitor already returned, so there is never a second one).

main()
{
    // the sniper perma perk (earn: 5 long-range sniper kills in a round; lose: 3 misses in a row) only knows the SVU,
    // DSR-50 and Barrett; on DLC5 maps the Ballista counts too (user request). Same replaceFunc form as DLC5's own scripts.
    // the red Insta-Kill icon (upgraded Insta-Kill perma perk) is the "insta_kill_ug" powerup's HUD slot, and stock only
    // registers a powerup the map included - only Kino and Ascension include this one, so on the other DLC5 maps the icon
    // never showed. Included here before the map's own setup runs (zzz_dlc5_permaperks.csc does the same client side).
    if ( nmlpp_is_dlc5_map() )
    {
        if ( !isdefined( level.zombie_include_powerups ) )
            level.zombie_include_powerups = [];

        level.zombie_include_powerups["insta_kill_ug"] = 1;
    }

    // PhD Flopper perma perk: its explosion sets clientfield "phd_flopper_effects" (Buried registers it, no DLC5 map
    // does, so there was no effect). Registered here and in zzz_dlc5_permaperks.csc on the maps that load PhD's
    // explosion effect and sound (Ascension, Shangri-La, Moon).
    if ( dlc5pp_has_phd_fx() )
        registerclientfield( "allplayers", "phd_flopper_effects", 12000, 1, "int" );

    if ( nmlpp_is_dlc5_map() )
    {
        f = getfunction( "maps/mp/zombies/_zm_pers_upgrades_functions", "is_sniper_weapon" );

        if ( isdefined( f ) )
            replacefunc( f, ::nmlpp_is_sniper_weapon, -1 );
    }
}

// stock list + the Ballista (ballista_zm / ballista_upgraded_zm)
nmlpp_is_sniper_weapon( weapon )
{
    if ( !isdefined( weapon ) || !isstring( weapon ) )
        return false;

    if ( getsubstr( weapon, 0, 4 ) == "svu_" || getsubstr( weapon, 0, 6 ) == "dsr50_" || getsubstr( weapon, 0, 10 ) == "barretm82_" )
        return true;

    return getsubstr( weapon, 0, 9 ) == "ballista_";
}

init()
{
    if ( !nmlpp_is_dlc5_map() )
        return;

    if ( isdefined( level.zombie_powerups ) && isdefined( level.zombie_powerups["insta_kill_ug"] ) )
        println( "PERMAPERKS >> red Insta-Kill icon registered" );
    else
        println( "PERMAPERKS >> red Insta-Kill icon NOT registered" );

    // on by default: off only when the PERMA PERKS lobby option was set to DISABLED
    if ( getdvar( "dlc5_permaperks" ) == "0" )
    {
        println( "PERMAPERKS >> off (lobby option not set)" );
        return;
    }

    level.pers_upgrade_boards = 1;
    level.pers_upgrade_revive = 1;
    level.pers_upgrade_multi_kill_headshots = 1;
    level.pers_upgrade_cash_back = 1;
    level.pers_upgrade_insta_kill = 1;
    level.pers_upgrade_jugg = 1;
    level.pers_upgrade_carpenter = 1;
    level.pers_upgrade_flopper = 1;
    level.pers_upgrade_perk_lose = 1;
    level.pers_upgrade_pistol_points = 1;
    level.pers_upgrade_double_points = 1;
    level.pers_upgrade_sniper = 1;
    level.pers_upgrade_box_weapon = 1;
    // Nube (Olympia wall buy -> Ray Gun) is switched on later in nmlpp_late_init, with its round-10 rule removed
    level thread nmlpp_late_init();
}

dlc5pp_has_phd_fx()
{
    switch ( getdvar( "mapname" ) )
    {
        case "zm_cosmodrome":
        case "zm_temple":
        case "zm_moon":
            return true;
    }

    return false;
}

nmlpp_is_dlc5_map()
{
    switch ( getdvar( "mapname" ) )
    {
        case "zm_prototype":
        case "zm_asylum":
        case "zm_sumpf":
        case "zm_factory":
        case "zm_theater":
        case "zm_pentagon":
        case "zm_cosmodrome":
        case "zm_temple":
        case "zm_moon":
            return true;
    }

    return false;
}

nmlpp_late_init()
{
    level endon( "end_game" );

    while ( getplayers().size == 0 )
        wait 0.1;

    wait 1;

    level.pers_upgrade_nube = 1;

    if ( isdefined( level.pers_upgrades ) && isdefined( level.pers_upgrades_keys ) && level.pers_upgrades_keys.size > 0 )
    {
        maps\mp\zombies\_zm_pers_upgrades::setup_pers_upgrade_nube();
        println( "PERMAPERKS >> on - stock registered the others, nube added" );
    }
    else
        maps\mp\zombies\_zm_pers_upgrades::pers_upgrade_init();

    // user request: no "never reached round 10" rule for Nube (stock locks it to accounts whose best round is under
    // 10, and takes it away at round 10). Set after setup, which puts it back to 10.
    level.pers_nube_lose_round = 9999;

    // the per-player Nube watcher normally starts on connect; players already here get it now (later joiners the stock way)
    foreach ( player in getplayers() )
        player thread maps\mp\zombies\_zm_pers_upgrades_functions::pers_nube_unlock_watcher();

    count = 0;

    if ( isdefined( level.pers_upgrades_keys ) )
        count = level.pers_upgrades_keys.size;

    println( "PERMAPERKS >> on - " + count + " perma perks on " + getdvar( "mapname" ) + ", nube round limit removed" );
}
