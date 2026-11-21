#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_score;
#include maps\mp\zombies\_zm_audio;
#include maps\mp\zombies\_zm_weapons;

init()
{
    level.spikemore_detonate_radius = 96.0;
    level.spikemore_fire_radius = 200.0;
    level.spikemore_projectile_damage = 1500;
    level.spikemore_projectile_speed = 1500;
    level.spikemore_detectionangle = 50.0;

    level thread _update_spikemore_fires();

    precacheitem( "spikemore_zm" );
    precachemodel( "p_ztem_spikemore_spike" );

    if ( !isdefined( level._effect ) )
        level._effect = [];

    if ( !isdefined( level._effect["fx_ztem_spikemore"] ) )
        level._effect["fx_ztem_spikemore"] = loadfx( "maps/zombie_temple/fx_ztem_spikemore" );

    level._cf_scriptmover_client_flag_spikemore = 5;
    level._cf_actor_client_flag_spikemore = 7;

    trigs = getentarray( "spikemore_purchase", "targetname" );

    for ( i = 0; i < trigs.size; i++ )
    {
        model = getent( trigs[i].target, "targetname" );

        if ( isdefined( model ) )
            model hide();
    }

    array_thread( trigs, ::buy_spikemores );
    level thread give_spikemores_after_rounds();

    level.pickup_spikemores = ::pickup_spikemores;
    level.pickup_spikemores_trigger_listener = ::pickup_spikemores_trigger_listener;
    level.spikemore_detectiondot = cos( 70 );
    level.spikemore_detectionmindist = 20;

    maps\mp\zombies\_zm_utility::register_placeable_mine_for_level( "spikemore_zm" );

    level._spikeable_objects = [];
    level.create_level_specific_weaponobject_watchers = ::create_spikemore_watcher_zm;
}

create_spikemore_watcher_zm()
{

}

add_spikeable_object( ent )
{
    level._spikeable_objects = add_to_array( level._spikeable_objects, ent, 0 );
}

remove_spikeable_object( ent )
{
    level._spikeable_objects = arrayremovevalue( level._spikeable_objects, ent );
}

buy_spikemores()
{
    self.zombie_cost = 1000;
    self sethintstring( &"ZOMBIE_TEMPLE_SPIKEMORE_PURCHASE" );
    self setcursorhint( "HINT_NOICON" );
    level thread set_spikemore_visible();
    self.spikemores_triggered = 0;

    while ( true )
    {
        self waittill( "trigger", who );

        if ( who in_revive_trigger() )
            continue;

        if ( who has_powerup_weapon() )
        {
            wait 0.1;
            continue;
        }

        if ( is_player_valid( who ) )
        {
            if ( who.score >= self.zombie_cost )
            {
                if ( !who is_player_placeable_mine( "spikemore_zm" ) )
                {
                    play_sound_at_pos( "purchase", self.origin );
                    who maps\mp\zombies\_zm_score::minus_to_player_score( self.zombie_cost );
                    who thread spikemore_setup();
                    who thread show_spikemore_hint( "spikemore_purchased" );
                    who thread maps\mp\zombies\_zm_audio::create_and_play_dialog( "weapon_pickup", "spikemore" );

                    if ( self.spikemores_triggered == 0 )
                    {
                        model = getent( self.target, "targetname" );

                        if ( isdefined( model ) )
                            model thread maps\mp\zombies\_zm_weapons::weapon_show( who );

                        self.spikemores_triggered = 1;
                    }

                    trigs = getentarray( "spikemore_purchase", "targetname" );

                    for ( i = 0; i < trigs.size; i++ )
                        trigs[i] setinvisibletoplayer( who );
                }
                else
                    who thread show_spikemore_hint( "already_purchased" );
            }
            else
                who maps\mp\zombies\_zm_audio::create_and_play_dialog( "general", "no_money", undefined, 1 );
        }
    }
}

set_spikemore_visible()
{
    players = getplayers();
    trigs = getentarray( "spikemore_purchase", "targetname" );

    while ( true )
    {
        for ( j = 0; j < players.size; j++ )
        {
            if ( !players[j] is_player_placeable_mine( "spikemore_zm" ) )
            {
                for ( i = 0; i < trigs.size; i++ )
                    trigs[i] setinvisibletoplayer( players[j], 0 );
            }
        }

        wait 1;
        players = getplayers();
    }
}

spikemore_watch()
{
    self endon( "death" );
    self endon( "disconnect" );

    while ( true )
    {
        self waittill( "grenade_fire", spikemore, weapname );

        if ( weapname == "spikemore_zm" )
        {
            spikemore.owner = self;
            spikemore.team = self.team;

            if ( is_true( self.is_on_minecart ) )
                spikemore _spikemore_smallspearactivate();
            else
                spikemore thread spikemore_detonation();

            self notify( "zmb_enable_spikemore_prompt" );
        }
    }
}

spikemore_setup()
{
    self thread spikemore_watch();
    self giveweapon( "spikemore_zm" );
    self set_player_placeable_mine( "spikemore_zm" );
    self setactionslot( 4, "weapon", "spikemore_zm" );
    self setweaponammostock( "spikemore_zm", 4 );
}

pickup_spikemores()
{
    player = self.owner;

    if ( !player hasweapon( "spikemore_zm" ) )
    {
        player thread spikemore_watch();
        player giveweapon( "spikemore_zm" );
        player set_player_placeable_mine( "spikemore_zm" );
        player setactionslot( 4, "weapon", "spikemore_zm" );
        player setweaponammoclip( "spikemore_zm", 0 );
        player notify( "zmb_enable_spikemore_prompt" );
    }
    else
    {
        clip_ammo = player getweaponammoclip( self.name );
        clip_max_ammo = weaponclipsize( self.name );

        if ( clip_ammo >= clip_max_ammo )
        {
            player notify( "zmb_disable_spikemore_prompt" );
            return;
        }
    }

    clip_ammo = player getweaponammoclip( self.name );
    clip_max_ammo = weaponclipsize( self.name );

    if ( clip_ammo >= clip_max_ammo )
        player notify( "zmb_disable_spikemore_prompt" );
}

pickup_spikemores_trigger_listener( trigger, player )
{
    self thread pickup_spikemores_trigger_listener_enable( trigger, player );
    self thread pickup_spikemores_trigger_listener_disable( trigger, player );
}

pickup_spikemores_trigger_listener_enable( trigger, player )
{
    self endon( "delete" );
    self endon( "death" );

    while ( true )
    {
        player waittill_any( "zmb_enable_spikemore_prompt", "spawned_player" );

        if ( !isdefined( trigger ) )
            return;

        trigger trigger_on();
        trigger linkto( self );
    }
}

pickup_spikemores_trigger_listener_disable( trigger, player )
{
    self endon( "delete" );
    self endon( "death" );

    while ( true )
    {
        player waittill( "zmb_disable_spikemore_prompt" );

        if ( !isdefined( trigger ) )
            return;

        trigger unlink();
        trigger trigger_off();
    }
}

shouldaffectweaponobject( object )
{
    pos = self.origin + vectorscale( ( 0, 0, 1 ), 32.0 );
    dirtopos = pos - object.origin;
    objectforward = anglestoforward( object.angles );
    dist = vectordot( dirtopos, objectforward );

    if ( dist < level.spikemore_detectionmindist )
        return false;

    dirtopos = vectornormalize( dirtopos );
    dot = vectordot( dirtopos, objectforward );
    return dot > level.spikemore_detectiondot;
}

spikemore_detonation()
{
    self endon( "death" );
    self waittill_not_moving();

    detonateradius = level.spikemore_detonate_radius;
    damagearea = spawn( "trigger_radius", self.origin + ( 0, 0, 0 - detonateradius ), 4, detonateradius, detonateradius * 2 );

    if ( isdefined( self.team ) )
        damagearea setexcludeteamfortrigger( self.team );
    else if ( isdefined( self.owner ) && isdefined( self.owner.team ) )
        damagearea setexcludeteamfortrigger( self.owner.team );

    damagearea enablelinkto();
    damagearea linkto( self );
    self thread delete_spikemores_on_death( damagearea );

    if ( !isdefined( level.spikemores ) )
        level.spikemores = [];

    level.spikemores[level.spikemores.size] = self;

    if ( level.spikemores.size > 15 && getdvar( #"player_sustainAmmo" ) != "0" )
        level.spikemores[0] delete();

    while ( true )
    {
        damagearea waittill( "trigger", ent );

        if ( !isdefined( ent ) )
            continue;

        if ( isdefined( self.owner ) && ent == self.owner )
            continue;

        if ( isplayer( ent ) )
            continue;

        if ( is_true( ent.nuked ) || is_true( ent.marked_for_death ) )
            continue;

        if ( isai( ent ) && isdefined( ent.health ) && ent.health <= 0 )
            continue;

        if ( !ent shouldaffectweaponobject( self ) )
            continue;

        if ( ent damageconetrace( self.origin, self ) > 0 )
        {
            self _spikemore_smallspearactivate( ent );
            return;
        }
    }
}

delete_spikemores_on_death( ent )
{
    self waittill( "death" );
    level.spikemores = arrayremovevalue( level.spikemores, self );
    wait 0.05;

    if ( isdefined( ent ) )
        ent delete();
}

give_spikemores_after_rounds()
{
    while ( true )
    {
        level waittill( "between_round_over" );
        players = get_players();

        for ( i = 0; i < players.size; i++ )
        {
            if ( players[i] is_player_placeable_mine( "spikemore_zm" ) )
            {
                players[i] giveweapon( "spikemore_zm" );
                players[i] set_player_placeable_mine( "spikemore_zm" );
                players[i] setactionslot( 4, "weapon", "spikemore_zm" );
                players[i] setweaponammoclip( "spikemore_zm", 2 );
            }
        }
    }
}

init_hint_hudelem( x, y, alignx, aligny, fontscale, alpha )
{
    self.x = x;
    self.y = y;
    self.alignx = alignx;
    self.aligny = aligny;
    self.fontscale = fontscale;
    self.alpha = alpha;
    self.sort = 20;
}

setup_client_hintelem()
{
    self endon( "death" );
    self endon( "disconnect" );

    if ( !isdefined( self.hintelem ) )
        self.hintelem = newclienthudelem( self );

    self.hintelem init_hint_hudelem( 320, 220, "center", "bottom", 1.6, 1.0 );
}

show_spikemore_hint( string )
{
    self endon( "death" );
    self endon( "disconnect" );

    if ( string == "spikemore_purchased" )
        text = &"ZOMBIE_TEMPLE_SPIKEMORE_HOWTO";
    else
        text = &"ZOMBIE_TEMPLE_SPIKEMORE_ALREADY_PURCHASED";

    self setup_client_hintelem();
    self.hintelem settext( text );
    wait 3.5;
    self.hintelem settext( "" );
}

_getzombiesinrange( range )
{
    ret = [];
    range2 = range * range;
    zombies = getaiarray( "axis" );

    if ( isdefined( level._spikeable_objects ) )
        zombies = arraycombine( zombies, level._spikeable_objects, 1, 0 );

    for ( i = 0; i < zombies.size; i++ )
    {
        if ( !isdefined( zombies[i] ) )
            continue;

        checkdist2 = distancesquared( zombies[i].origin, self.origin );

        if ( checkdist2 < range2 )
        {
            zombie = zombies[i];

            if ( is_true( zombie.nuked ) || is_true( zombie.marked_for_death ) )
                continue;

            if ( isai( zombie ) && isdefined( zombie.health ) && zombie.health <= 0 )
                continue;

            ret[ret.size] = zombie;
        }
    }

    return ret;
}

_spikemore_targetinfov( target )
{
    totarget = target.origin - self.origin;
    totarget = ( totarget[0], totarget[1], 0.0 );
    totarget = vectornormalize( totarget );
    forward = anglestoforward( ( 0.0, self.angles[1], 0.0 ) );
    dot = vectordot( totarget, forward );
    return dot >= level.spikemore_detectiondot;
}

_spikemore_filtertargetsbyfov( targets )
{
    ret = [];

    for ( i = 0; i < targets.size; i++ )
    {
        if ( !isdefined( targets[i] ) )
            continue;

        if ( self _spikemore_targetinfov( targets[i] ) )
            ret[ret.size] = targets[i];
    }

    if ( ret.size == 0 && isdefined( targets ) && targets.size > 0 )
        return targets;

    return ret;
}

_spikemore_smallspearactivate( trigger_ent )
{
    _wait_to_fire_spikemore();

    targets = self _getzombiesinrange( level.spikemore_fire_radius );
    targets = self _spikemore_filtertargetsbyfov( targets );

    if ( !isdefined( targets ) )
        targets = [];

    if ( isdefined( trigger_ent ) )
    {
        found = false;

        for ( i = 0; i < targets.size; i++ )
        {
            if ( targets[i] == trigger_ent )
            {
                found = true;
                break;
            }
        }

        if ( !found )
            targets[targets.size] = trigger_ent;
    }

    fireorigin = self.origin;
    fireangles = self.angles;
    self _spikemore_smallspeardetonate( targets, fireorigin, fireangles );
    wait 0.25;
    self delete();
}

_spikemore_smallspeardetonate( targets, fireorigin, fireangles )
{
    if ( !isdefined( fireorigin ) )
        fireorigin = self.origin;

    if ( !isdefined( fireangles ) )
        fireangles = self.angles;

    self playsound( "claymore_activated_SP" );
    wait 0.4;
    self setclientflag( level._cf_scriptmover_client_flag_spikemore );
    self playsound( "wpn_spikemore_exp" );

    playfx( level._effect["fx_ztem_spikemore"], fireorigin, anglestoforward( fireangles ) );
    level thread _spikemore_spawn_flying_spikes( fireorigin, fireangles );

    for ( i = 0; i < targets.size; i++ )
    {
        if ( !isdefined( targets[i] ) )
            continue;

        if ( isai( targets[i] ) )
        {
            targets[i] thread _spikemore_damage( fireorigin, self.owner );
            continue;
        }

        targets[i] notify( "spiked", self.owner );
    }

    wait 0.1;
}

_spikemore_spawn_flying_spikes( origin, angles )
{
    for ( i = 0; i < 3; i++ )
    {
        yaw = randomfloatrange( angles[1] - level.spikemore_detectionangle, angles[1] + level.spikemore_detectionangle );
        forward = anglestoforward( ( 0.0, yaw, 0.0 ) );
        z = randomfloatrange( 100.0, 150.0 );
        dest = origin + forward * 400.0 + ( 0, 0, z );
        trace = bullettrace( origin, dest, 0, undefined );

        if ( isdefined( trace ) && isdefined( trace["position"] ) )
            level thread _spikemore_fly_one_spike( origin, trace["position"], vectortoangles( forward ) );
    }
}

_spikemore_fly_one_spike( start, dest, angles )
{
    dist = distance( start, dest );
    time = dist / level.spikemore_projectile_speed;

    if ( time < 0.05 )
        time = 0.05;

    if ( time > 0.4 )
        time = 0.4;

    e = spawn( "script_model", start );
    e setmodel( "p_ztem_spikemore_spike" );
    e.angles = angles + vectorscale( ( 0, 1, 0 ), 90.0 );
    e moveto( dest, time );
    wait( time );
    wait 8.0;

    if ( isdefined( e ) )
        e delete();
}

_spikemore_attach_spikes_to_zombie()
{
    if ( !isdefined( self ) )
        return;

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

    attached = 0;

    for ( i = 0; i < j.size && attached < 3; i++ )
    {
        joint = j[i];
        jointpos = self gettagorigin( joint );

        if ( !isdefined( jointpos ) )
            continue;

        e = spawn( "script_model", jointpos );
        e setmodel( "p_ztem_spikemore_spike" );
        e.angles = self.angles + ( randomintrange( -30, 30 ), randomintrange( -180, 180 ), randomintrange( -30, 30 ) );
        e linkto( self, joint );
        e thread _spikemore_delete_spike_later( 10 );
        attached++;
    }
}

_spikemore_delete_spike_later( t )
{
    wait( t );

    if ( isdefined( self ) )
        self delete();
}

_spikemore_damage( fromorigin, fromowner )
{
    if ( !isdefined( self ) )
        return;

    numspikes = 2;

    if ( randomint( 10 ) == 0 )
        numspikes++;

    zombiedamage = level.spikemore_projectile_damage * numspikes;
    dist = distance( fromorigin, self.origin );
    time = dist / level.spikemore_projectile_speed;

    if ( time > 0.35 )
        time = 0.35;

    wait( time );

    if ( !isdefined( self ) || !isalive( self ) )
        return;

    if ( isdefined( self.animname ) && self.animname == "napalm_zombie" )
        return;

    self.no_gib = 1;
    self _spikemore_attach_spikes_to_zombie();

    if ( isdefined( level._cf_actor_client_flag_spikemore ) )
        self setclientflag( level._cf_actor_client_flag_spikemore );

    if ( isdefined( fromowner ) && randomintrange( 0, 101 ) <= 75 )
        fromowner thread maps\mp\zombies\_zm_audio::create_and_play_dialog( "kill", "spikemore" );

    self dodamage( zombiedamage, fromorigin, fromowner );
}

_update_spikemore_fires()
{
    while ( true )
    {
        level.hasspikemorefiredrecently = 0;
        wait 0.2;
    }
}

_wait_to_fire_spikemore()
{
    while ( is_true( level.hasspikemorefiredrecently ) )
        wait_network_frame();

    level.hasspikemorefiredrecently = 1;
}