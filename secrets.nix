let
  legion = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINkzZmMq6uptsXTpgmNwY+Ketuh51aGN6MwrWeMnV+ii root@legion";

in
{
  "configs/secrets/haslo-user.age".publicKeys = [ legion ];

}
