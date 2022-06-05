Msg("Activating Firewall\n");

IncludeScript("vslib_firewall");

Utils.PrecacheModel( "models/survivors/survivor_biker.mdl" );
Utils.PrecacheModel( "models/survivors/survivor_manager.mdl" );
Utils.PrecacheModel( "models/survivors/survivor_namvet.mdl" );
Utils.PrecacheModel( "models/survivors/survivor_teenangst.mdl" );

// Méthodes utiles pour plus tard
// VSLib::Player::CanSeeLocation(targetPos, tolerance = 50)
// VSLib::Player::CanSeeOtherEntity(otherEntity, tolerance = 50)

MutationOptions <-
{
  ActiveChallenge = 1
  cm_AllowSurvivorRescue = 0
  cm_CommonLimit = 0
  cm_DominatorLimit = 0
  cm_MaxSpecials = 0
  cm_NoSurvivorBots = 1
  SurvivorMaxIncapacitatedCount = 0
      
  weaponsToRemove =
  {
    weapon_melee = 0
    weapon_chainsaw = 0
    weapon_pipe_bomb = 0
    weapon_vomitjar = 0
    weapon_first_aid_kit = 0
    weapon_defibrillator = 0
    weapon_upgradepack_incendiary = 0
    weapon_upgradepack_explosive = 0
  }

  function AllowWeaponSpawn(classname)
  {
    if (classname in weaponsToRemove)
    {
      return false;
    }
    
    return true;
  }
}

MutationState <-
{
  AliveSurvivors = 4,
  Message = ""
}

::RoundState <-
{
  Active = false
  Number = 0
  Players = {}
}

function Notifications::OnSurvivorsLeftStartArea::DoStuff()
{  
  RoundState.Number++;
  RoundState.Active = true;
}

function Notifications::OnRoundStart::LoadStats()
{  
  RoundState.Active = false;
  RestoreTable("RoundData", RoundState);
  
  foreach (key,player in RoundState.Players)
  {
    player.alive = true;
  }
}

function Notifications::OnSurvivorsDead::RetainStats()
{  
  SaveTable("RoundData", RoundState);
}

//
// Only molotovs and tanks can harm players
//
function EasyLogic::OnTakeDamage::AllowDamage(damageTable)
{
  if (!RoundState.Active)
  {
    return false;
  }

  local attacker = Utils.GetEntityOrPlayer(damageTable.Attacker);
  local victim = Utils.GetEntityOrPlayer(damageTable.Victim);
  
  try
  {
    if (victim.GetPlayerType() == Z_TANK)
    {
      return true;
    }
  
    if (attacker.GetPlayerType() == Z_SURVIVOR && damageTable.DamageType != DMG_BURN)
    {
      return false;
    }
  }
  catch( error )
  {
  }

  return true;
}

function Notifications::OnPlayerJoined::DetectPlayers(player, name, IPAddress, SteamID, params)
{
  if (player.GetPlayerType() != Z_SURVIVOR)
  {
    return;
  }
  
  try
  {
    RoundState.Players[player.GetUniqueID()];

    // Already there
    return;
  }
  catch(error)
  {
  }
  
  EntFire("player", "SetGlowEnabled", "0");

  // lowercase attributes as SaveTable and RestoreTable mangle the Case
  RoundState.Players[player.GetUniqueID()] <- 
  {
    nickname = name,
    kills = 0,
    deaths = 0,
    points = 0,
    alive = true
  };
  
  if (RoundState.Active)
  {
    player.Kill();
  }
}

function Notifications::OnPlayerLeft::DetectPlayers(player, name, SteamID, params)
{
  if (player.GetType() != Z_SURVIVOR)
  {
    return;
  }
  
  delete RoundState.Players[player.GetUniqueID()];

  g_ModeScript.CheckEnd();
}

function Notifications::OnDeath::SurvivorDeath(victim, attacker, params)
{    
  if (victim.GetType() != Z_SURVIVOR || !RoundState.Active)
  {
    return;
  }
  
  RoundState.Players[victim.GetUniqueID()].alive = false;
  RoundState.Players[victim.GetUniqueID()].deaths++;
  
  // Only survivor kills (death from falling -> attacker null)
  if (attacker != null && attacker.GetType() == Z_SURVIVOR)
  {
    RoundState.Players[attacker.GetUniqueID()].kills++;
  }

  g_ModeScript.CheckEnd();
}

function CheckEnd()
{
  local winner = null;

  foreach (key,player in RoundState.Players)
  {    
    if (player.alive)
    {
      if (winner != null)
      {
        return;
      }
      
      winner = player;
    }
  }
    
  if (winner == null)
  {
    g_ModeScript.ShowMessage("No one scores!");
    return;
  }
  
  winner.points++;
  
  g_ModeScript.ShowMessage(winner.nickname + " scores!");
  
  foreach (surv in Players.AliveSurvivors())
  {
    surv.SetLastStrike();
  }
  
  Utils.SlowTime(0.2, 10.0, 1.0, 2.0, true);
}

function GetScores()
{
  local text = "";

  if (RoundState.Number > 0)
  {
    text += "Round " + RoundState.Number + "\n";
  }

  foreach (idx,player in RoundState.Players)
  {
    text += player.nickname + ": " + player.points + "\n";
  }
  
  return text;
}

FirewallHUD <-
{
  Fields = 
  {
    scores = 
    { 
      slot = HUD_MID_BOX,
      name = "scores",
      datafunc = @() g_ModeScript.GetScores(),
      flags = HUD_FLAG_ALIGN_LEFT | HUD_FLAG_NOBG
    }
    message =
    {
      slot = HUD_MID_BOT,
      name = "message",
      datafunc = @() SessionState.Message,
      flags = HUD_FLAG_NOTVISIBLE | HUD_FLAG_NOBG
    }
  }
}

function SetupModeHUD( )
{
  HUDPlace(HUD_MID_BOX, 0.00, 0.00, 1.0, 0.2);
  
  HUDSetLayout(FirewallHUD);
}

function ShowMessage(message)
{
  SessionState.Message = message;
  FirewallHUD.Fields["message"].flags = FirewallHUD.Fields["message"].flags & ~HUD_FLAG_NOTVISIBLE;
}

function HideMessage()
{
  FirewallHUD.Fields["message"].flags = FirewallHUD.Fields["message"].flags & ~HUD_FLAG_NOTVISIBLE;
}
