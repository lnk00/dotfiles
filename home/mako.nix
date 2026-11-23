{ ... }:

{
  # D-Bus-activated on the first notification; nothing to autostart
  services.mako = {
    enable = true;
    settings = {
      # mako's default keeps every notification until it's clicked
      default-timeout = 5000;
      "urgency=critical".default-timeout = 0;
    };
  };
}
