multi_rel { 'internal':
  type         => 'package',
  match        => 'title',
  pattern      => 'foo',
  relationship => before,
}

package { ['foo', 'bar', 'baz']:
  ensure  => present,
  tag     => 'internal',
}

yumrepo { 'internal':
  ensure   => 'present',
  baseurl  => 'file:///var/yum/mirror/centos/7/os/x86_64',
  descr    => 'Locally stored packages for base_local',
  enabled  => '1',
  gpgcheck => '0',
  priority => '10',
  before   => Multi_rel['internal'],
}

## Will cause a dependency cycle!
# package { 'bugger':
#   ensure  => present,
#   tag     => 'internal',
#   before  => Yumrepo['internal'],
# }
