#include common_scripts\utility;
#include maps\mp\_utility;

// Fr0sty - DLC5 additions. Written by Fr0sty; please credit Fr0sty if you reuse or reupload any of this.
// Moon: the round change theme did not play. Log lines start with "MOONMUSIC >>".
// BO2's _zm_audio::change_zombie_music ignores a state that is the same as the last one played, so round_start only
// sounds again after a round_end. BO1's Moon round loop played round_end at the end of every Moon round; on DLC5's
// Moon only round_start is sent (Logo2K's round HUD script), so after the first time every round_start was dropped.
// This sends round_end at the end of each Moon round and round_start at the start (not in No Man's Land, like BO1,
// where the radar alarm evt_nomans_warning is the round-change sound), and logs what the music code sees.

main()
{
}

init()
{
    if ( getdvar( "mapname" ) != "zm_moon" )
        return;

    level thread moonmusic_watch( "end_of_round", "round_end" );
    level thread moonmusic_watch( "start_of_round", "round_start" );
}

moonmusic_watch( note, state )
{
    level endon( "end_game" );
    fp = getfunction( "maps/mp/zombies/_zm_audio", "change_zombie_music" );

    if ( !isdefined( fp ) )
    {
        println( "MOONMUSIC >> change_zombie_music not found" );
        return;
    }

    for (;;)
    {
        level waittill( note );

        if ( isdefined( level.flag ) && isdefined( level.flag["enter_nml"] ) && flag( "enter_nml" ) )
            continue;

        // let the map's own call (if any) go first; a repeat of the same state is ignored by the music code
        wait 1.5;
        old = "none";

        if ( isdefined( level.old_music_state ) && isdefined( level.old_music_state.music ) )
            old = level.old_music_state.music;

        println( "MOONMUSIC >> " + state + " (round " + level.round_number + ", music_override " + moonmusic_val( level.music_override ) + ", round_override " + moonmusic_val( level.music_round_override ) + ", last " + old + ")" );
        level thread [[ fp ]]( state );
    }
}

moonmusic_val( v )
{
    if ( !isdefined( v ) )
        return "undefined";

    return v;
}
