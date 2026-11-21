#include clientscripts\mp\_utility;
#include clientscripts\mp\_fx;
#include clientscripts\mp\zombies\_zm_utility;

init()
{
    if ( getdvar( #"createfx" ) == "on" )
        return;

    if ( !isdefined( level._cf_scriptmover_client_flag_spikemore ) )
        level._cf_scriptmover_client_flag_spikemore = 5;

    if ( !isdefined( level._cf_actor_client_flag_spikemore ) )
        level._cf_actor_client_flag_spikemore = 7;

    register_clientflag_callback( "scriptmover", level._cf_scriptmover_client_flag_spikemore, ::spikemore_detonate );
    register_clientflag_callback( "actor", level._cf_actor_client_flag_spikemore, ::spikemore_add_spikes );

    level.spikemore_fired_recently = 0;
    level.recent_spikemore_fire_origin = ( 0, 0, 0 );
    level.recent_spikemore_fire_angles = ( 0, 0, 0 );
    level.spikemore_detectionangle = 50.0;
    level.spikemore_detectiondot = cos( level.spikemore_detectionangle );
    level.spikemore_projectile_speed = 1500;
}

_set_recently_fired( origin, angles )
{
    level.recent_spikemore_fire_origin = origin;
    level.recent_spikemore_fire_angles = angles;
}

spikemore_detonate( local_client_num, int_set, ent_new )
{
    playsound( local_client_num, "wpn_spikemore_impact", self.origin );
    _set_recently_fired( self.origin, self.angles );

    if ( isdefined( level._effect ) && isdefined( level._effect["fx_ztem_spikemore"] ) )
        playfx( local_client_num, level._effect["fx_ztem_spikemore"], self.origin, anglestoforward( self.angles ) );

    for ( i = 0; i < 3; i++ )
    {
        yaw = randomfloatrange( level.recent_spikemore_fire_angles[1] - level.spikemore_detectionangle, level.recent_spikemore_fire_angles[1] + level.spikemore_detectionangle );
        forward = anglestoforward( ( 0.0, yaw, 0.0 ) );
        z = randomfloatrange( 100.0, 150.0 );
        dest = level.recent_spikemore_fire_origin + forward * 400.0 + ( 0, 0, z );
        trace = bullettrace( level.recent_spikemore_fire_origin, dest, 0, undefined );

        if ( isdefined( trace ) && trace["fraction"] < 1.0 )
            level thread _spawn_spear( local_client_num, trace, vectortoangles( forward ) );
    }
}

_spawn_spear( local_client_num, trace, angles )
{
    dist = distance( trace["position"], level.recent_spikemore_fire_origin );
    time = dist / level.spikemore_projectile_speed;
    wait( time );
    e = spawn( local_client_num, trace["position"], "script_model" );
    e.angles = angles + vectorscale( ( 0, 1, 0 ), 90.0 );
    e setmodel( "p_ztem_spikemore_spike" );
    delayed_remove( e );
}

spikemore_add_spikes( local_client_num, int_set, ent_new )
{
    j = [];
    j[j.size] = "J_SpineLower";
    j[j.size] = "J_Elbow_LE";
    j[j.size] = "J_Elbow_RI";
    j[j.size] = "J_Head";
    j[j.size] = "J_Clavicle_RI";
    j[j.size] = "J_Clavicle_LE";
    j[j.size] = "J_Hip_LE";
    j[j.size] = "J_Hip_RI";
    j = array_randomize( j );

    for ( i = 0; i < 3 && i < j.size; i++ )
    {
        joint = j[i];
        jointpos = self gettagorigin( joint );

        if ( !isdefined( jointpos ) )
            continue;

        e = spawn( local_client_num, jointpos, "script_model" );
        e setmodel( "p_ztem_spikemore_spike" );
        e linkto( self, joint );
        self thread delayed_remove_or_ent_shutdown( e );
    }
}

spikemore_waittill_notify_or_timeout( msg, timer )
{
    self endon( msg );
    wait( timer );
}

delayed_remove_or_ent_shutdown( ent )
{
    self spikemore_waittill_notify_or_timeout( "entityshutdown", 10 );

    if ( isdefined( ent ) )
        ent delete();
}

delayed_remove( ent )
{
    wait 10.0;

    if ( isdefined( ent ) )
        ent delete();
}