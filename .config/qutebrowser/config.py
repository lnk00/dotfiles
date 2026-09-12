config.load_autoconfig()

# Dark mode is enabled globally (see autoconfig.yml).
# Exclude specific sites here by adding one line per URL pattern:
config.set('colors.webpage.darkmode.enabled', False, 'http://localhost:*/*')
config.set('colors.webpage.darkmode.enabled', False, 'https://*.fullenrich.com')

# Notification permission: pinned here (not just autoconfig.yml) so it survives
# any autoconfig rewrite. Covers slack.com + every subdomain (app., <workspace>.).
config.set('content.notifications.enabled', True, 'https://*.slack.com')
