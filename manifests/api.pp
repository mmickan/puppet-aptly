# == Class: aptly::api
#
# Install and configure Aptly's API Service
#
# === Parameters
#
# [*ensure*]
#   Ensure to pass on to service type
#   Default: running
#
# [*user*]
#   User to run the service as.
#   Default: root
#
# [*group*]
#   Group to run the service as.
#   Default: root
#
# [*listen*]
#   What IP/port to listen on for API requests.
#   Default: ':8080'
#
# [*log*]
#   Enable or disable Upstart logging.
#   Default: none
#
# [*enable_cli_and_http*]
#   Enable concurrent use of command line (CLI) and HTTP APIs with
#   the same Aptly root.
#
# [*init_style*]
#   Type of service to deploy - upstart or systemd
#
class aptly::api (
  $ensure              = running,
  $user                = 'root',
  $group               = 'root',
  $listen              = ':8080',
  $log                 = 'none',
  $enable_cli_and_http = false,
  $init_style          = undef,
  ) {

    validate_re($ensure, ['^stopped|running$'], 'Valid values for $ensure: stopped, running')

    validate_string($user, $group)

    validate_re($listen, ['^[0-9.]*:[0-9]+$'], 'Valid values for $listen: :port, <ip>:<port>')

    validate_re($log, ['^none|log$'], 'Valid values for $log: none, log')

    if $init_style {
      validate_re($init_style, '^(upstart|systemd)$', 'Valid values for $init_style: upstart, systemd')
      $_init_style = $init_style
    } else {
      case $::operatingsystem {
        'Ubuntu': {
          if versioncmp($::operatingsystemrelease, '15.04') < 0 {
            $_init_style = 'upstart'
          } else {
            $_init_style = 'systemd'
          }
        }
        'Debian': {
          if versioncmp($::operatingsystemrelease, '8.0') < 0 {
            fail('Unsupported OS')
          } else {
            $_init_style = 'systemd'
          }
        }
        default: {
          fail('Unsupported OS')
        }
      }
    }

    case $_init_style {
      'upstart': {
        file{ '/etc/init/aptly-api.conf':
          content => template('aptly/etc/aptly.init.erb'),
          owner   => 'root',
          group   => 'root',
          mode    => '0444',
        } ~> Service['aptly-api']
      }
      'systemd': {
        file { '/lib/systemd/system/aptly-api.service':
          content => template('aptly/etc/aptly.systemd.erb'),
          owner   => 'root',
          group   => 'root',
          mode    => '0444',
        } ~>
        exec { 'aptly-api-systemd-reload':
          command     => 'systemctl daemon-reload',
          path        => [ '/usr/bin', '/bin', '/usr/sbin' ],
          refreshonly => true,
        } ~> Service['aptly-api']
      }
      default: { fail('should not reach this default case!') }
    }

    service{'aptly-api':
      ensure => $ensure,
      enable => true,
    }

}
