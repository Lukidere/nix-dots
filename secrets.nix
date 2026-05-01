let
  legion = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMEX1Ja0Tkcp/bW75Y12iwZKMAo/6VFwkvUJQ24qN4kF koniecznyrad@gmail.com";
in
{
  "configs/secrets/haslo-user.age".publicKeys = [ legion ];

}
