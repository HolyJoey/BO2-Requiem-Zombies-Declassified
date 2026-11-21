// Fr0sty - DLC5 additions. Written by Fr0sty; please credit Fr0sty if you reuse or reupload any of this.
// Client half of the red Insta-Kill icon fix (see zzz_dlc5_permaperks.gsc): the upgraded Insta-Kill perma perk's icon
// is the "insta_kill_ug" powerup's HUD slot, which stock only registers when the map includes it (only Kino and
// Ascension do). Included here before the map's own client setup, the same way those two maps do it.

main()
{
    if ( !dlc5pp_is_dlc5_map() )
        return;

    if ( !isdefined( level.zombie_include_powerups ) )
        level.zombie_include_powerups = [];

    level.zombie_include_powerups["insta_kill_ug"] = 1;

    // PhD Flopper perma perk explosion effect (Buried's callback); see zzz_dlc5_permaperks.gsc
    switch ( getdvar( "mapname" ) )
    {
        case "zm_cosmodrome":
        case "zm_temple":
        case "zm_moon":
            registerclientfield( "allplayers", "phd_flopper_effects", 12000, 1, "int", ::dlc5pp_flopper_effects, 0 );
            break;
    }
}

// Buried's buried_phd_flopper_effects
dlc5pp_flopper_effects( localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwasdemojump )
{
    if ( newval )
    {
        if ( isdefined( level._effect["divetonuke_groundhit"] ) )
            playfx( localclientnum, level._effect["divetonuke_groundhit"], self.origin );

        if ( localclientnum == 0 )
            self playsound( localclientnum, "zmb_phdflop_explo" );
    }
}

init()
{
    if ( !dlc5pp_is_dlc5_map() )
        return;

    if ( isdefined( level.zombie_powerups ) && isdefined( level.zombie_powerups["insta_kill_ug"] ) )
        println( "PERMAPERKS >> client: red Insta-Kill icon registered" );
    else
        println( "PERMAPERKS >> client: red Insta-Kill icon NOT registered" );
}

dlc5pp_is_dlc5_map()
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
