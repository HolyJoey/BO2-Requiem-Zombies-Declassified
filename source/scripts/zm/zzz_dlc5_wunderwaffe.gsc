#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;

// Fr0sty - DLC5 additions. Written by Fr0sty; please credit Fr0sty if you reuse or reupload any of this.
// Wunderwaffe DG-2 box odds like BO1 (Der Riese, Shi No Numa - any map with tesla_gun_zm in the box). Log: "WUNDER >>".
// DLC5's box picks every weapon with the same chance (~1 in 40). BO1's box (default_tesla_weighting_func) gave the
// Wunderwaffe extra entries on top of its normal one, counted from all the map's weapons (N):
//   - nobody has been offered it yet: after round 5 +15% of N, after round 10 +20% of N
//   - someone swapped it away for a box weapon: +20% of N for the rest of the game
// BO2's box picks the first weapon of a shuffled list the player can take, so this puts the Wunderwaffe first often
// enough to give it exactly that weight. The box's own "offered" flag (level.player_seen_tesla_gun) is used as-is.

main()
{
}

init()
{
    level thread wunder_setup();
}

wunder_setup()
{
    level endon( "end_game" );
    wait 1;

    if ( !isdefined( level.zombie_weapons ) || !isdefined( level.zombie_weapons["tesla_gun_zm"] ) )
        return;

    if ( !is_true( level.zombie_weapons["tesla_gun_zm"].is_in_box ) )
        return;

    level.wunder_prev_weights = level.customrandomweaponweights;
    level.customrandomweaponweights = ::wunder_box_weights;
    level thread wunder_drop_watch();
    println( "WUNDER >> BO1 Wunderwaffe box odds on " + getdvar( "mapname" ) );
}

// BO1's default_tesla_weighting_func: how many entries the Wunderwaffe gets (every other weapon has 1)
wunder_weight()
{
    // BO1 counted its included weapons (about the box's size there). DLC5 includes well over 100 (every BO2 gun it
    // knows), which made the boost 2-3x BO1's, so N is the number of weapons actually in this box.
    n = 0;
    keys = getarraykeys( level.zombie_weapons );

    for ( i = 0; i < keys.size; i++ )
    {
        if ( is_true( level.zombie_weapons[keys[i]].is_in_box ) )
            n++;
    }

    num = 1;

    if ( is_true( level.player_drops_tesla_gun ) )
        num = num + int( 0.2 * n );

    if ( !is_true( level.player_seen_tesla_gun ) )
    {
        if ( level.round_number > 10 )
            num = num + int( 0.2 * n );
        else if ( level.round_number > 5 )
            num = num + int( 0.15 * n );
    }

    return num;
}

// self = the player using the box; keys = the box's shuffled weapon list
wunder_box_weights( keys )
{
    if ( isdefined( level.wunder_prev_weights ) )
        keys = self [[ level.wunder_prev_weights ]]( keys );

    w = wunder_weight();

    if ( w <= 1 )
        return keys;

    pap = getentarray( "specialty_weapupgrade", "script_noteworthy" );

    if ( !maps\mp\zombies\_zm_magicbox::treasure_chest_canplayerreceiveweapon( self, "tesla_gun_zm", pap ) )
        return keys;

    // how many weapons this player could get right now (the Wunderwaffe included)
    e = 0;

    for ( i = 0; i < keys.size; i++ )
    {
        if ( maps\mp\zombies\_zm_magicbox::treasure_chest_canplayerreceiveweapon( self, keys[i], pap ) )
            e++;
    }

    if ( e <= 1 )
        return keys;

    // BO1 chance w / ( w + e - 1 ); the shuffled list already gives it 1 / e, so put it first often enough for the rest
    chance = ( w * 1.0 ) / ( w + e - 1 );
    first = ( chance - 1.0 / e ) / ( 1 - 1.0 / e );

    if ( randomfloat( 1 ) < first )
    {
        arrayremovevalue( keys, "tesla_gun_zm" );
        arrayinsert( keys, "tesla_gun_zm", 0 );
        println( "WUNDER >> box gives the Wunderwaffe (BO1 chance " + int( chance * 100 ) + "%, round " + level.round_number + ")" );
    }

    return keys;
}

// BO1: a player swapping the Wunderwaffe away sets player_drops_tesla_gun for the rest of the game
wunder_drop_watch()
{
    level endon( "end_game" );

    while ( !is_true( level.player_drops_tesla_gun ) )
    {
        wait 0.5;

        foreach ( player in getplayers() )
        {
            has = player hasweapon( "tesla_gun_zm" ) || player hasweapon( "tesla_gun_upgraded_zm" );

            if ( is_true( player.wunder_had ) && !has && isalive( player ) && !player maps\mp\zombies\_zm_laststand::player_is_in_laststand() && player.sessionstate == "playing" )
            {
                level.player_drops_tesla_gun = 1;
                println( "WUNDER >> " + player.name + " swapped the Wunderwaffe away: +20% for the rest of the game" );
            }

            player.wunder_had = has;
        }
    }
}
